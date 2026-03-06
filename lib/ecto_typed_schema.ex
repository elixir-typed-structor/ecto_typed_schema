defmodule EctoTypedSchema do
  @doc """
  Sets up the module to use EctoTypedSchema.

  - Enables TypedStructor without defining a struct  
  - Enables Ecto.Schema
  - Registers accumulation attribute for captured custom options
  - Imports typed_schema macros and FieldCapture wrappers
  - Registers @before_compile callback for TypedStructor generation
  """
  defmacro __using__(_opts) do
    quote location: :keep do
      use TypedStructor, define_struct: false
      use Ecto.Schema
      # undo exports to avoid conflicts
      import Ecto.Schema, only: []

      @before_compile EctoTypedSchema
      @on_definition {EctoTypedSchema, :on_def}
      Module.register_attribute(__MODULE__, :ecto_typed_schema_typed, accumulate: true)
      Module.register_attribute(__MODULE__, :ecto_typed_schema_parameters, accumulate: true)
      Module.register_attribute(__MODULE__, :ecto_typed_schema_opts, [])

      import EctoTypedSchema,
        only: [
          typed_schema: 2,
          typed_schema: 3,
          typed_embedded_schema: 1,
          typed_embedded_schema: 2
        ]
    end
  end

  @doc false
  def on_def(env, :def, :__changeset__, [], [], body) do
    Module.put_attribute(env.module, :ecto_typed_schema_changeset_body, body)
  end

  def on_def(_env, _kind, _name, _args, _guards, _body), do: :ok

  @doc """
  @before_compile callback to generate TypedStructor type definitions.
  """
  defmacro __before_compile__(env) do
    changeset_info =
      env.module
      |> Module.get_attribute(:ecto_typed_schema_changeset_body)
      |> EctoTypedSchema.ChangesetExtractor.extract()

    typeds = Module.get_attribute(env.module, :ecto_typed_schema_typed, [])
    schema_opts = Module.get_attribute(env.module, :ecto_typed_schema_opts, [])
    schema_source = Module.get_attribute(env.module, :ecto_typed_schema_source)
    primary_keys = Module.get_attribute(env.module, :ecto_primary_keys, [])

    # Get all fields from changeset info
    changeset_fields = Keyword.keys(changeset_info)

    # Through associations (e.g., `has_many :post_tags, through: [:posts, :tags]`) are NOT
    # included in Ecto's `__changeset__/0` function, but they ARE registered as associations
    # and captured via our typed macros. We need to handle these fields separately.
    typed_only_fields =
      for {field, _opts} <- typeds,
          field not in changeset_fields,
          do: field

    fields_ast =
      for {ecto_field, ecto_type} <- changeset_info do
        {type_opts, typed} =
          typeds
          |> Keyword.get(ecto_field, [])
          |> Keyword.split([:type])

        # Apply schema-level options before generating the type
        typed = merge_schema_opts(typed, schema_opts)

        # Primary keys are always non-nullable (auto-generated or required)
        typed =
          if ecto_field in primary_keys do
            Keyword.put(typed, :null, false)
          else
            typed
          end

        field_type =
          EctoTypedSchema.TypeMapper.to_elixir_type(ecto_type, Keyword.merge(type_opts, typed))

        # Special handling for associations and embeds with cardinality :many
        typed =
          case ecto_type do
            {:assoc, %{cardinality: :many}} ->
              # has_many and many_to_many always return lists, never nil
              # Force them to be non-nullable
              typed |> Keyword.put(:null, false) |> Keyword.put(:default, [])

            {:embed, %{cardinality: :many}} ->
              # embeds_many always returns lists, never nil
              # Force them to be non-nullable with default []
              typed |> Keyword.put(:null, false) |> Keyword.put(:default, [])

            _ ->
              typed
          end

        quote do
          field unquote(ecto_field), unquote(field_type), unquote(typed)
        end
      end

    # Handle fields that only exist in typed (like through associations)
    assocs = Module.get_attribute(env.module, :ecto_assocs) || []

    additional_fields_ast =
      for field <- typed_only_fields do
        {type_opts, typed} =
          typeds
          |> Keyword.get(field, [])
          |> Keyword.split([:type])

        # Apply schema-level options before generating the type
        typed = merge_schema_opts(typed, schema_opts)

        case Keyword.fetch(typed, :through) do
          {:ok, through} ->
            # Through association — resolve the target schema
            cardinality =
              case List.keyfind(assocs, field, 0) do
                {_, %{cardinality: c}} -> c
                _ -> :many
              end

            # If user provided a type override, use it directly
            {field_type, typed} =
              case Keyword.fetch(type_opts, :type) do
                {:ok, custom_type} ->
                  typed =
                    case cardinality do
                      :many ->
                        typed |> Keyword.put(:null, false) |> Keyword.put(:default, [])

                      :one ->
                        typed
                    end

                  {custom_type, typed}

                :error ->
                  case resolve_through_schema(env, assocs, through) do
                    nil ->
                      case cardinality do
                        :one ->
                          {quote(do: term()), typed}

                        :many ->
                          {quote(do: list(term())),
                           typed |> Keyword.put(:null, false) |> Keyword.put(:default, [])}
                      end

                    target_schema ->
                      case cardinality do
                        :one ->
                          field_type =
                            quote(do: Ecto.Schema.has_one(unquote(target_schema).t()))

                          {field_type, typed}

                        :many ->
                          field_type =
                            quote(do: Ecto.Schema.has_many(unquote(target_schema).t()))

                          typed =
                            typed |> Keyword.put(:null, false) |> Keyword.put(:default, [])

                          {field_type, typed}
                      end
                  end
              end

            quote do
              field unquote(field), unquote(field_type), unquote(typed)
            end

          :error ->
            # Unknown field in typed but not in changeset — skip
            nil
        end
      end
      |> Enum.reject(&is_nil/1)

    # Read parameters (accumulate stores in reverse order)
    parameters =
      env.module
      |> Module.get_attribute(:ecto_typed_schema_parameters, [])
      |> Enum.reverse()

    # Build typed_structor options
    structor_opts = [define_struct: false]

    structor_opts =
      case Keyword.get(schema_opts, :type_kind) do
        nil -> structor_opts
        type_kind -> Keyword.put(structor_opts, :type_kind, type_kind)
      end

    structor_opts =
      case Keyword.get(schema_opts, :type_name) do
        nil -> structor_opts
        type_name -> Keyword.put(structor_opts, :type_name, type_name)
      end

    # Generate parameter AST for typed_structor block
    parameters_ast =
      for param <- parameters do
        name = Keyword.fetch!(param, :name)
        opts = Keyword.delete(param, :name)

        quote do
          parameter unquote(name), unquote(opts)
        end
      end

    # Check if this is an embedded schema
    # Embedded schemas are defined with embedded_schema/1 and don't have a source
    if is_nil(schema_source) do
      # Embedded schema - no __meta__ field
      quote do
        typed_structor unquote(structor_opts) do
          unquote(parameters_ast)
          unquote(fields_ast)
          unquote(additional_fields_ast)
        end
      end
    else
      # Regular schema with __meta__ field
      quote do
        typed_structor unquote(structor_opts) do
          unquote(parameters_ast)
          field :__meta__, Ecto.Schema.Metadata.t(__MODULE__), enforce: true
          unquote(fields_ast)
          unquote(additional_fields_ast)
        end
      end
    end
  end

  defp merge_schema_opts(field_opts, schema_opts) do
    schema_opts
    |> Keyword.take([:enforce, :null])
    |> Keyword.merge(field_opts)
  end

  defp resolve_through_schema(_env, assocs, through_path) when is_list(through_path) do
    # Start from the current module being compiled and traverse the association chain
    # The first step needs special handling because the current module isn't fully compiled yet
    [first_step | rest_steps] = through_path

    case List.keyfind(assocs, first_step, 0) do
      {_, first_assoc} ->
        # Get the related schema from the first association
        initial_schema = first_assoc.related

        # For remaining steps, the schemas should be compiled and have __schema__/2
        final_schema =
          Enum.reduce_while(rest_steps, initial_schema, fn step_name, current_schema ->
            if Code.ensure_loaded?(current_schema) and
                 function_exported?(current_schema, :__schema__, 2) do
              case current_schema.__schema__(:association, step_name) do
                nil -> {:halt, nil}
                assoc -> {:cont, assoc.related}
              end
            else
              {:halt, nil}
            end
          end)

        if final_schema do
          quote do: unquote(final_schema)
        else
          nil
        end

      nil ->
        # Association not found
        nil
    end
  end

  @doc """
  Defines a typed Ecto schema that delegates directly to Ecto.Schema.schema/2.

  Supports an optional third argument for schema-level options.

  ## Options

  All options are passed directly to TypedStructor for type generation:

    * `:default` - sets the default value for the field
    * `:enforce` - if set to `true`, enforces the field
    * `:null` - if set to `false`, makes the field type non-nullable

  > ### How `:default`, `:enforce` and `:null` affect `type` and `@enforce_keys` {: .tip}
  >
  > The null option behavior follows TypedStructor's implementation:
  > - `null: false` makes the type non-nullable (e.g., `String.t()` instead of `String.t() | nil`)
  > - `null: true` or unset allows nullable types
  > - The `null` option only affects the type definition, not the struct field's actual default value
  > - If both `default` and `null: false` are set, the type will be non-nullable
  > - If both `enforce: true` and `null: false` are set, the field is required and non-nullable
  """
  defmacro typed_schema(source, do: block) do
    quote location: :keep do
      @ecto_typed_schema_source unquote(source)
      @ecto_typed_schema_opts []

      Ecto.Schema.schema unquote(source) do
        import Ecto.Schema, only: []
        import EctoTypedSchema.FieldMacros
        unquote(block)
      end
    end
  end

  defmacro typed_schema(source, opts, do: block) do
    quote location: :keep do
      @ecto_typed_schema_source unquote(source)
      @ecto_typed_schema_opts unquote(opts)

      Ecto.Schema.schema unquote(source) do
        import Ecto.Schema, only: []
        import EctoTypedSchema.FieldMacros
        unquote(block)
      end
    end
  end

  @doc """
  Defines a typed embedded Ecto schema that delegates to `Ecto.Schema.embedded_schema/1`.

  This macro is used for schemas that are embedded in other schemas (via `embeds_one`
  or `embeds_many`) rather than stored in their own database table. Embedded schemas
  do not have a `__meta__` field in their generated type.

  ## Type Generation

  Generates a `@type t()` specification for the embedded schema struct. The type
  includes all fields defined within the block, with types inferred from their
  Ecto types or customized via the `:typed` option.

  Unlike regular schemas:
    * No `__meta__` field is included in the type
    * No `:id` field is automatically added (unless explicitly defined or via `:primary_key` option)

  ## Field Macros

  Inside the `typed_embedded_schema` block, you can use all field macros from
  `EctoTypedSchema.FieldMacros`:

    * `field/3` - Define a typed field
    * `embeds_one/3,4` - Embed another schema (one-to-one)
    * `embeds_many/3,4` - Embed multiple schemas (one-to-many)
    * `timestamps/1` - Add timestamp fields

  Note: Association macros (`belongs_to`, `has_one`, `has_many`, `many_to_many`)
  are not typically used in embedded schemas.

  ## Examples

      defmodule Address do
        use EctoTypedSchema

        # Generates @type t() :: %__MODULE__{
        #   id: binary() | nil,
        #   street: String.t() | nil,
        #   city: String.t() | nil,
        #   zip: String.t() | nil
        # }
        typed_embedded_schema do
          field :street, :string
          field :city, :string
          field :zip, :string
        end
      end

  See `typed_embedded_schema/2` for schema-level options.
  """
  defmacro typed_embedded_schema(do: block) do
    quote location: :keep do
      Ecto.Schema.embedded_schema do
        import Ecto.Schema, only: []
        import EctoTypedSchema.FieldMacros
        unquote(block)
      end
    end
  end

  @doc """
  Defines a typed embedded Ecto schema with schema-level options.

  This variant accepts options that apply to all fields in the schema,
  similar to `typed_schema/3`.

  ## Options

  Schema-level options that apply to all fields:

    * `:enforce` - If `true`, adds all fields to `@enforce_keys` (unless overridden per-field)
    * `:null` - If `false`, makes all field types non-nullable (unless overridden per-field)

  Individual fields can override these options via their `:typed` option.

  ## Type Generation

  Same as `typed_embedded_schema/1`, but with schema-level options applied:

    * When `enforce: true`, all fields are added to `@enforce_keys`
    * When `null: false`, all field types become non-nullable

  ## Examples

      defmodule Settings do
        use EctoTypedSchema

        # All fields are non-nullable
        # Generates @type t() :: %__MODULE__{
        #   id: binary() | nil,
        #   theme: String.t(),
        #   notifications_enabled: boolean()
        # }
        typed_embedded_schema null: false do
          field :theme, :string
          field :notifications_enabled, :boolean
        end
      end

      defmodule Config do
        use EctoTypedSchema

        # All fields are enforced (required at struct creation)
        # Generates @type t() :: %__MODULE__{
        #   id: binary() | nil,
        #   api_key: String.t(),
        #   timeout: integer()
        # }
        typed_embedded_schema enforce: true do
          field :api_key, :string
          field :timeout, :integer
        end
      end

      defmodule Metadata do
        use EctoTypedSchema

        # Field-level options override schema-level options
        # Generates @type t() :: %__MODULE__{
        #   id: binary() | nil,
        #   version: integer(),
        #   description: String.t() | nil
        # }
        typed_embedded_schema null: false do
          field :version, :integer
          field :description, :string, typed: [null: true]  # Override: nullable
        end
      end
  """
  defmacro typed_embedded_schema(opts, do: block) do
    quote location: :keep do
      # Store schema-level options in module attribute
      @ecto_typed_schema_opts unquote(opts)

      Ecto.Schema.embedded_schema do
        import Ecto.Schema, only: []
        import EctoTypedSchema.FieldMacros
        unquote(block)
      end
    end
  end
end
