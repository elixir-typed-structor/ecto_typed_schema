defmodule EctoTypedSchema do
  @external_resource "README.md"

  @moduledoc "README.md"
             |> File.read!()
             |> String.split("<!-- MODULEDOC -->", parts: 3)
             |> Enum.fetch!(1)
             |> Kernel.<>("""

             ## Typed Options

             Pass `typed: [...]` on any field or association to customize its generated type:

             | Option | Effect |
             | --- | --- |
             | `type:` | Override the inferred type entirely |
             | `null:` | `false` removes `\\| nil` from the type |
             | `enforce:` | `true` adds the field to `@enforce_keys` |
             | `default:` | Struct default; non-nil defaults imply non-nullable |

             ```elixir
             field :email, :string, typed: [null: false, enforce: true]
             field :role, :string, typed: [type: :admin | :user]
             ```

             For `belongs_to`, the `:foreign_key` sub-option controls the FK field's type:

             ```elixir
             belongs_to :org, Organization,
               foreign_key: :org_id,
               typed: [foreign_key: [type: Ecto.UUID.t()]]
             ```

             ## Schema-level Options

             `typed_schema/3` and `typed_embedded_schema/2` accept options that apply as
             defaults to every field (per-field `typed:` options override):

             ```elixir
             typed_schema "users", null: false, enforce: true do
               field :name, :string
               field :bio, :string, typed: [null: true]  # override: nullable
             end
             ```

             | Option | Effect |
             | --- | --- |
             | `null:` | Default nullability for all fields |
             | `enforce:` | Default enforce for all fields |
             | `type_kind:` | `:opaque`, `:typep`, etc. (default `:type`) |
             | `type_name:` | Custom type name (default `:t`) |
             """)

  @doc false
  @spec __using__(keyword()) :: Macro.t()
  defmacro __using__(_opts) do
    quote location: :keep do
      use TypedStructor, define_struct: false
      use Ecto.Schema
      # Undo Ecto.Schema exports to avoid conflicts with our wrappers.
      import Ecto.Schema, only: []

      @before_compile EctoTypedSchema
      @on_definition {EctoTypedSchema, :on_def}
      Module.register_attribute(__MODULE__, :ecto_typed_schema_typed, accumulate: true)
      Module.register_attribute(__MODULE__, :ecto_typed_schema_parameters, accumulate: true)
      Module.register_attribute(__MODULE__, :ecto_typed_schema_plugins, accumulate: true)
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
  @spec on_def(Macro.Env.t(), atom(), atom(), list(), list(), term()) :: :ok
  def on_def(env, :def, :__changeset__, [], [], body) do
    Module.put_attribute(env.module, :ecto_typed_schema_changeset_body, body)
  end

  def on_def(_env, _kind, _name, _args, _guards, _body), do: :ok

  @doc false
  @spec __before_compile__(Macro.Env.t()) :: Macro.t()
  defmacro __before_compile__(env) do
    changeset_info =
      env.module
      |> Module.get_attribute(:ecto_typed_schema_changeset_body)
      |> EctoTypedSchema.ChangesetExtractor.extract()

    override_map =
      env.module
      |> Module.get_attribute(:ecto_typed_schema_typed, [])
      |> Map.new()

    schema_opts = Module.get_attribute(env.module, :ecto_typed_schema_opts, [])
    schema_defaults = Keyword.take(schema_opts, [:enforce, :null])
    primary_keys = Module.get_attribute(env.module, :ecto_primary_keys, [])

    fields_ast = build_fields_ast(changeset_info, override_map, schema_defaults, primary_keys)

    additional_fields_ast =
      build_additional_fields_ast(env, changeset_info, override_map, schema_defaults)

    parameters_ast = build_parameters_ast(env)
    plugins_ast = build_plugins_ast(env)
    structor_opts = build_structor_opts(schema_opts)
    schema_source = Module.get_attribute(env.module, :ecto_typed_schema_source)

    emit_typed_structor(
      schema_source,
      structor_opts,
      plugins_ast,
      parameters_ast,
      fields_ast,
      additional_fields_ast
    )
  end

  # Builds typed_structor field AST for each field in the Ecto changeset.
  @spec build_fields_ast([{atom(), term()}], map(), keyword(), [atom()]) :: [Macro.t()]
  defp build_fields_ast(changeset_info, override_map, schema_defaults, primary_keys) do
    for {ecto_field, ecto_type} <- changeset_info do
      typed =
        override_map
        |> Map.get(ecto_field, [])
        |> merge_schema_opts(schema_defaults)
        |> maybe_force_primary_key(ecto_field, primary_keys)
        |> maybe_force_many_defaults(ecto_type)

      field_type = EctoTypedSchema.TypeMapper.to_elixir_type(ecto_type, typed)

      quote do
        field unquote(ecto_field), unquote(field_type), unquote(typed)
      end
    end
  end

  # Primary keys are always non-nullable.
  @spec maybe_force_primary_key(keyword(), atom(), [atom()]) :: keyword()
  defp maybe_force_primary_key(typed, field, primary_keys) do
    if field in primary_keys, do: Keyword.put(typed, :null, false), else: typed
  end

  # :many cardinality associations/embeds always return lists, never nil.
  @spec maybe_force_many_defaults(keyword(), term()) :: keyword()
  defp maybe_force_many_defaults(typed, {:assoc, %{cardinality: :many}}),
    do: force_list_defaults(typed)

  defp maybe_force_many_defaults(typed, {:embed, %{cardinality: :many}}),
    do: force_list_defaults(typed)

  defp maybe_force_many_defaults(typed, _ecto_type), do: typed

  # Builds typed_structor field AST for through-association fields not in the changeset.
  @spec build_additional_fields_ast(Macro.Env.t(), [{atom(), term()}], map(), keyword()) ::
          [Macro.t()]
  defp build_additional_fields_ast(env, changeset_info, override_map, schema_defaults) do
    changeset_field_set = MapSet.new(Keyword.keys(changeset_info))

    typed_only_fields =
      override_map
      |> Map.keys()
      |> Enum.reject(&MapSet.member?(changeset_field_set, &1))

    if typed_only_fields == [] do
      []
    else
      assocs = Module.get_attribute(env.module, :ecto_assocs) || []

      typed_only_fields
      |> Enum.map(fn field ->
        typed =
          override_map
          |> Map.get(field, [])
          |> merge_schema_opts(schema_defaults)

        build_through_field_ast(env.module, field, typed, assocs)
      end)
      |> Enum.reject(&is_nil/1)
    end
  end

  # Builds quoted `parameter` calls from accumulated parameter attributes.
  @spec build_parameters_ast(Macro.Env.t()) :: [Macro.t()]
  defp build_parameters_ast(env) do
    env.module
    |> Module.get_attribute(:ecto_typed_schema_parameters, [])
    |> Enum.reverse()
    |> Enum.map(fn param ->
      name = Keyword.fetch!(param, :name)
      opts = Keyword.delete(param, :name)

      quote do
        parameter unquote(name), unquote(opts)
      end
    end)
  end

  # Builds quoted `plugin` calls from accumulated plugin attributes.
  @spec build_plugins_ast(Macro.Env.t()) :: [Macro.t()]
  defp build_plugins_ast(env) do
    env.module
    |> Module.get_attribute(:ecto_typed_schema_plugins, [])
    |> Enum.reverse()
    |> Enum.map(fn {plugin, opts} ->
      quote do
        plugin unquote(plugin), unquote(opts)
      end
    end)
  end

  # Builds the options keyword list for `typed_structor`.
  @spec build_structor_opts(keyword()) :: keyword()
  defp build_structor_opts(schema_opts) do
    [define_struct: false]
    |> maybe_put(:type_kind, Keyword.get(schema_opts, :type_kind))
    |> maybe_put(:type_name, Keyword.get(schema_opts, :type_name))
  end

  # Emits the final `typed_structor` block.
  # Embedded schemas (nil source) omit the `__meta__` field.
  @spec emit_typed_structor(
          binary() | nil,
          keyword(),
          [Macro.t()],
          [Macro.t()],
          [Macro.t()],
          [Macro.t()]
        ) :: Macro.t()
  defp emit_typed_structor(nil, opts, plugins, parameters, fields, additional_fields) do
    quote do
      typed_structor unquote(opts) do
        unquote(plugins)
        unquote(parameters)
        unquote(fields)
        unquote(additional_fields)
      end
    end
  end

  defp emit_typed_structor(_source, opts, plugins, parameters, fields, additional_fields) do
    quote do
      typed_structor unquote(opts) do
        unquote(plugins)
        unquote(parameters)
        field :__meta__, Ecto.Schema.Metadata.t(__MODULE__), enforce: true
        unquote(fields)
        unquote(additional_fields)
      end
    end
  end

  # Merges precomputed schema-level defaults (`:enforce`, `:null`) with
  # per-field options. Field-level options take precedence.
  @spec merge_schema_opts(keyword(), keyword()) :: keyword()
  defp merge_schema_opts(field_opts, schema_defaults) do
    Keyword.merge(schema_defaults, field_opts)
  end

  # Forces non-nullable with default `[]` for :many cardinality fields.
  @spec force_list_defaults(keyword()) :: keyword()
  defp force_list_defaults(typed) do
    typed
    |> Keyword.put(:null, false)
    |> Keyword.put(:default, [])
  end

  # Conditionally puts a key into a keyword list; skips nil values.
  @spec maybe_put(keyword(), atom(), term()) :: keyword()
  defp maybe_put(keyword, _key, nil), do: keyword
  defp maybe_put(keyword, key, value), do: Keyword.put(keyword, key, value)

  # Builds a typed_structor field AST for a through-association field.
  # Returns nil if the field has no `:through` key (should be skipped).
  @spec build_through_field_ast(module(), atom(), keyword(), list()) :: Macro.t() | nil
  defp build_through_field_ast(module, field, typed, assocs) do
    case Keyword.fetch(typed, :through) do
      {:ok, through} ->
        cardinality =
          case List.keyfind(assocs, field, 0) do
            {_, %{cardinality: c}} -> c
            _ -> :many
          end

        {field_type, typed} =
          case Keyword.fetch(typed, :type) do
            {:ok, custom_type} ->
              typed =
                if cardinality == :many,
                  do: force_list_defaults(typed),
                  else: typed

              {custom_type, Keyword.delete(typed, :type)}

            :error ->
              resolve_through_type(module, field, typed, assocs, through, cardinality)
          end

        quote do
          field unquote(field), unquote(field_type), unquote(typed)
        end

      :error ->
        # Unknown field in typed but not in changeset -- skip.
        nil
    end
  end

  # Resolves the Elixir type for a through-association by traversing the
  # association chain to find the target schema.
  @spec resolve_through_type(module(), atom(), keyword(), list(), [atom()], :one | :many) ::
          {Macro.t(), keyword()}
  defp resolve_through_type(module, field, typed, assocs, through, cardinality) do
    case resolve_through_schema(assocs, through) do
      nil ->
        warn_unresolved_through(module, field, through, cardinality)

        case cardinality do
          :one ->
            {quote(do: term()), typed}

          :many ->
            {quote(do: list(term())), force_list_defaults(typed)}
        end

      target_schema ->
        case cardinality do
          :one ->
            {quote(do: Ecto.Schema.has_one(unquote(target_schema).t())), typed}

          :many ->
            {quote(do: Ecto.Schema.has_many(unquote(target_schema).t())),
             force_list_defaults(typed)}
        end
    end
  end

  # Emits a compile-time warning when a through-association chain cannot be resolved.
  @spec warn_unresolved_through(module(), atom(), [atom()], :one | :many) :: :ok
  defp warn_unresolved_through(module, field, through, cardinality) do
    fallback = if cardinality == :one, do: "term()", else: "list(term())"
    path = Enum.map_join(through, ", ", &inspect/1)

    IO.warn(
      "#{inspect(module)}: field :#{field} through association [#{path}] " <>
        "could not be resolved at compile time. Falling back to #{fallback}. " <>
        "To specify the type explicitly, use typed: [type: ...]"
    )
  end

  # Walks the association chain to resolve the final target schema.
  # Returns a quoted module reference or nil if resolution fails.
  @spec resolve_through_schema(list(), [atom()]) :: Macro.t() | nil
  defp resolve_through_schema(assocs, through_path) when is_list(through_path) do
    [first_step | rest_steps] = through_path

    case List.keyfind(assocs, first_step, 0) do
      {_, first_assoc} ->
        initial_schema = first_assoc.related

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
        nil
    end
  end

  # Builds delegation AST for wrapper macros that forward to FieldMacros.
  defp delegate_to_field_macros(name, args) do
    quote do
      require EctoTypedSchema.FieldMacros
      EctoTypedSchema.FieldMacros.unquote(name)(unquote_splicing(args))
    end
  end

  @doc group: "Type Customization"
  @doc """
  Declares a type parameter for the schema's generated type.

  Parameters make the generated type parameterized, e.g., `@type t(age) :: %__MODULE__{...}`.
  They are passed through to `TypedStructor.parameter/2`.

  ## Examples

      typed_schema "users" do
        parameter :age

        field :name, :string
        field :age, :integer, typed: [type: age]
      end

  This generates `@type t(age) :: %__MODULE__{...}` where the `:age` field
  uses the type parameter instead of the inferred `integer()` type.
  """
  defmacro parameter(name, opts \\ []),
    do: delegate_to_field_macros(:parameter, [name, opts])

  @doc group: "Type Customization"
  @doc """
  Registers a `TypedStructor` plugin for the schema's generated type.

  Plugins are forwarded to the `typed_structor` block generated at compile time.
  They receive the `TypedStructor.Definition` and can modify types, add fields,
  or inject code before/after the struct definition.

  See `TypedStructor.Plugin` for the plugin behaviour and callbacks.

  ## Examples

      typed_schema "users" do
        plugin MyPlugin, some_option: true

        field :name, :string
      end
  """
  defmacro plugin(plugin, opts \\ []),
    do: delegate_to_field_macros(:plugin, [plugin, opts])

  @doc group: "Fields and Associations"
  @doc """
  Defines a typed schema field that wraps `Ecto.Schema.field/3`.

  ## Type Mapping

  The generated type is inferred from the Ecto type. Common mappings include:

  | Ecto Type | Elixir Typespec |
  |---|---|
  | `:string` | `String.t()` |
  | `:integer` | `integer()` |
  | `:float` | `float()` |
  | `:boolean` | `boolean()` |
  | `:binary` | `binary()` |
  | `:decimal` | `Decimal.t()` |
  | `:date` | `Date.t()` |
  | `:time` / `:time_usec` | `Time.t()` |
  | `:naive_datetime` / `:naive_datetime_usec` | `NaiveDateTime.t()` |
  | `:utc_datetime` / `:utc_datetime_usec` | `DateTime.t()` |
  | `:binary_id` | `Ecto.UUID.t()` |
  | `:map` | `map()` |
  | `{:array, inner}` | `list(inner_type)` |
  | `Ecto.Enum` | Union of atom values (e.g., `:active \| :inactive`) |
  | Custom module | `Module.t()` |

  `Ecto.Enum` values are automatically captured and used to generate a union type.

  See the ["Typed options"](`m:EctoTypedSchema#module-typed-options`) section in the
  module documentation for more options.

  ## Examples

      field :name, :string
      field :email, :string, typed: [null: false, enforce: true]
      field :role, Ecto.Enum, values: [:admin, :user, :guest]
  """
  defmacro field(name, type \\ :string, opts \\ []),
    do: delegate_to_field_macros(:field, [name, type, opts])

  @doc group: "Fields and Associations"
  @doc """
  Defines a typed `Ecto.Schema.belongs_to/3` association.

  Creates both the association field and its foreign key field. The association
  is nullable by default.

  ## Typed Options

    * `:foreign_key` - a keyword list to customize the foreign key field's type independently

  See the ["Typed options"](`m:EctoTypedSchema#module-typed-options`) section in the
  module documentation for more options.

  ## Examples

      belongs_to :user, User, typed: [null: false]
      belongs_to :organization, Organization,
        foreign_key: :org_id,
        typed: [foreign_key: [type: Ecto.UUID.t()]]
  """
  defmacro belongs_to(name, schema, opts \\ []),
    do: delegate_to_field_macros(:belongs_to, [name, schema, opts])

  @doc group: "Fields and Associations"
  @doc """
  Defines a typed `Ecto.Schema.has_one/3` association. Nullable by default.

  See the ["Typed options"](`m:EctoTypedSchema#module-typed-options`) section in the
  module documentation for more options.

  ## Examples

      has_one :profile, Profile
      has_one :settings, Settings, typed: [null: false]
  """
  defmacro has_one(name, schema, opts \\ []),
    do: delegate_to_field_macros(:has_one, [name, schema, opts])

  @doc group: "Fields and Associations"
  @doc """
  Defines a typed `Ecto.Schema.has_many/3` association. Always non-nullable
  (defaults to `[]`); the `:null` option has no effect.

  Also supports through-associations via `has_many :name, through: [:assoc, :chain]`.

  See the ["Typed options"](`m:EctoTypedSchema#module-typed-options`) section in the
  module documentation for more options.

  ## Examples

      has_many :posts, Post, foreign_key: :user_id
      has_many :post_tags, through: [:posts, :tags], typed: [type: list(Tag.t())]
  """
  defmacro has_many(name, schema, opts \\ []),
    do: delegate_to_field_macros(:has_many, [name, schema, opts])

  @doc group: "Fields and Associations"
  @doc """
  Defines a typed `Ecto.Schema.many_to_many/3` association. Always non-nullable
  (defaults to `[]`); the `:null` option has no effect.

  See the ["Typed options"](`m:EctoTypedSchema#module-typed-options`) section in the
  module documentation for more options.

  ## Examples

      many_to_many :tags, Tag, join_through: "posts_tags", typed: [type: list(Tag.t())]
  """
  defmacro many_to_many(name, schema, opts \\ []),
    do: delegate_to_field_macros(:many_to_many, [name, schema, opts])

  @doc group: "Fields and Associations"
  @doc """
  Equivalent to `embeds_one/4` without a block. See `embeds_one/4` for
  details and examples.
  """
  defmacro embeds_one(name, schema, opts \\ []),
    do: delegate_to_field_macros(:embeds_one, [name, schema, opts])

  @doc group: "Fields and Associations"
  @doc """
  Defines a typed `Ecto.Schema.embeds_one/3` embed. Nullable by default.

  The optional `do` block allows defining the embedded schema inline.

  See the ["Typed options"](`m:EctoTypedSchema#module-typed-options`) section in the
  module documentation for more options.

  ## Examples

      embeds_one :address, Address
      embeds_one :profile, Profile, typed: [null: false]

      embeds_one :address, Address, primary_key: false do
        field :street, :string
        field :city, :string
      end
  """
  defmacro embeds_one(name, schema, opts, do: block),
    do: delegate_to_field_macros(:embeds_one, [name, schema, opts, [do: block]])

  @doc group: "Fields and Associations"
  @doc """
  Equivalent to `embeds_many/4` without a block. See `embeds_many/4` for
  details and examples.
  """
  defmacro embeds_many(name, schema, opts \\ []),
    do: delegate_to_field_macros(:embeds_many, [name, schema, opts])

  @doc group: "Fields and Associations"
  @doc """
  Defines a typed `Ecto.Schema.embeds_many/3` embed. Always non-nullable
  (defaults to `[]`); the `:null` option has no effect.

  The optional `do` block allows defining the embedded schema inline.

  See the ["Typed options"](`m:EctoTypedSchema#module-typed-options`) section in the
  module documentation for more options.

  ## Examples

      embeds_many :addresses, Address, typed: [enforce: true]

      embeds_many :line_items, LineItem, primary_key: false do
        field :product_name, :string
        field :quantity, :integer
        field :price, :decimal
      end
  """
  defmacro embeds_many(name, schema, opts, do: block),
    do: delegate_to_field_macros(:embeds_many, [name, schema, opts, [do: block]])

  @doc group: "Fields and Associations"
  @doc """
  Defines typed timestamp fields that wrap `Ecto.Schema.timestamps/1`.

  The single `:typed` option applies to **both** generated timestamp fields.

  ## Timestamp Type Mapping

  | Ecto Type | Elixir Typespec |
  |---|---|
  | `:naive_datetime` (default) | `NaiveDateTime.t()` |
  | `:naive_datetime_usec` | `NaiveDateTime.t()` |
  | `:utc_datetime` | `DateTime.t()` |
  | `:utc_datetime_usec` | `DateTime.t()` |

  See the ["Typed options"](`m:EctoTypedSchema#module-typed-options`) section in the
  module documentation for more options.

  ## Examples

      timestamps()
      timestamps(type: :utc_datetime)
      timestamps(typed: [null: false])
  """
  defmacro timestamps(opts \\ []),
    do: delegate_to_field_macros(:timestamps, [opts])

  @doc group: "Schema"
  @doc """
  Defines a typed Ecto schema that delegates directly to `Ecto.Schema.schema/2`.

  Equivalent to `typed_schema(source, [], do: block)`.

  See `typed_schema/3` for options and examples.
  """
  @spec typed_schema(binary(), keyword()) :: Macro.t()
  defmacro typed_schema(source, do: block) do
    quote location: :keep do
      EctoTypedSchema.typed_schema(unquote(source), [], do: unquote(block))
    end
  end

  @doc group: "Schema"
  @doc """
  Defines a typed Ecto schema with schema-level options.

  Wraps `Ecto.Schema.schema/2` and captures type metadata for
  `@type t()` generation via `TypedStructor`.

  ## Schema-level Options

  Options that apply as defaults to every field (individual fields
  can override via their `:typed` option):

    * `:enforce` - if `true`, adds all fields to `@enforce_keys`
    * `:null` - if `false`, makes all field types non-nullable
    * `:type_kind` - the kind of type to generate (e.g., `:opaque`)
    * `:type_name` - custom name for the generated type (default: `:t`)

  See the ["Schema-level Options"](`m:EctoTypedSchema#module-schema-level-options`)
  section in the module documentation for more details.

  ## Examples

      typed_schema "users", null: false do
        field :name, :string
        field :bio, :string, typed: [null: true]  # override: nullable
      end
  """
  @spec typed_schema(binary(), keyword(), keyword()) :: Macro.t()
  defmacro typed_schema(source, opts, do: block) do
    quote location: :keep do
      @ecto_typed_schema_source unquote(source)
      @ecto_typed_schema_opts unquote(opts)

      Ecto.Schema.schema unquote(source) do
        import Ecto.Schema, only: []

        import EctoTypedSchema,
          only: [
            field: 1,
            field: 2,
            field: 3,
            belongs_to: 2,
            belongs_to: 3,
            has_one: 2,
            has_one: 3,
            has_many: 2,
            has_many: 3,
            many_to_many: 2,
            many_to_many: 3,
            embeds_one: 2,
            embeds_one: 3,
            embeds_one: 4,
            embeds_many: 2,
            embeds_many: 3,
            embeds_many: 4,
            timestamps: 0,
            timestamps: 1,
            parameter: 1,
            parameter: 2,
            plugin: 1,
            plugin: 2
          ]

        unquote(block)
      end
    end
  end

  @doc group: "Schema"
  @doc """
  Defines a typed embedded Ecto schema that delegates to `Ecto.Schema.embedded_schema/1`.

  Equivalent to `typed_embedded_schema([], do: block)`.

  See `typed_embedded_schema/2` for options and examples.
  """
  @spec typed_embedded_schema(keyword()) :: Macro.t()
  defmacro typed_embedded_schema(do: block) do
    quote location: :keep do
      EctoTypedSchema.typed_embedded_schema([], do: unquote(block))
    end
  end

  @doc group: "Schema"
  @doc """
  Defines a typed embedded Ecto schema with schema-level options.

  Wraps `Ecto.Schema.embedded_schema/1` and captures type metadata for
  `@type t()` generation. Embedded schemas do not include a `__meta__`
  field in their generated type.

  ## Schema-level Options

  Options that apply as defaults to every field (individual fields
  can override via their `:typed` option):

    * `:enforce` - if `true`, adds all fields to `@enforce_keys`
    * `:null` - if `false`, makes all field types non-nullable
    * `:type_kind` - the kind of type to generate (e.g., `:opaque`)
    * `:type_name` - custom name for the generated type (default: `:t`)

  See the ["Schema-level Options"](`m:EctoTypedSchema#module-schema-level-options`)
  section in the module documentation for more details.

  ## Examples

      typed_embedded_schema null: false do
        field :theme, :string
        field :bio, :string, typed: [null: true]  # override: nullable
      end
  """
  @spec typed_embedded_schema(keyword(), keyword()) :: Macro.t()
  defmacro typed_embedded_schema(opts, do: block) do
    quote location: :keep do
      @ecto_typed_schema_opts unquote(opts)

      Ecto.Schema.embedded_schema do
        import Ecto.Schema, only: []

        import EctoTypedSchema,
          only: [
            field: 1,
            field: 2,
            field: 3,
            belongs_to: 2,
            belongs_to: 3,
            has_one: 2,
            has_one: 3,
            has_many: 2,
            has_many: 3,
            many_to_many: 2,
            many_to_many: 3,
            embeds_one: 2,
            embeds_one: 3,
            embeds_one: 4,
            embeds_many: 2,
            embeds_many: 3,
            embeds_many: 4,
            timestamps: 0,
            timestamps: 1,
            parameter: 1,
            parameter: 2,
            plugin: 1,
            plugin: 2
          ]

        unquote(block)
      end
    end
  end
end
