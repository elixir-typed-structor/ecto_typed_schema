defmodule EctoTypedSchema.TypeMapper do
  @moduledoc """
  Module responsible for inferring Elixir types from Ecto types and generating
  association types.
  """

  @typedoc "Supported Ecto field types that can be converted to Elixir types"
  @type ecto_type() :: Ecto.Type.t() | {:assoc, Ecto.Association.t()}

  @doc """
  Infers the appropriate Elixir type specification from an Ecto field type.

  This function converts Ecto schema field types into their corresponding Elixir
  type specifications that can be used in `@type` definitions.

  ## Supported Basic Types

    * `:string` → `String.t()`
    * `:integer` → `integer()`
    * `:float` → `float()`
    * `:boolean` → `boolean()`
    * `:binary` → `binary()`
    * `:bitstring` → `bitstring()`
    * `:decimal` → `Decimal.t()`
    * `:id` → `integer()`
    * `:binary_id` → `binary()`
    * `:map` → `map()`
    * `:array` → `list()`

  ## Temporal Types

    * `:date` → `Date.t()`
    * `:time` → `Time.t()`
    * `:time_usec` → `Time.t()`
    * `:naive_datetime` → `NaiveDateTime.t()`
    * `:naive_datetime_usec` → `NaiveDateTime.t()`
    * `:datetime` → `DateTime.t()`
    * `:utc_datetime` → `DateTime.t()`
    * `:utc_datetime_usec` → `DateTime.t()`
    * `:duration` → `Duration.t()`

  ## Complex Types

    * `{:map, inner_type}` → `%{term() => inner_type}`
    * `{:array, inner_type}` → `list(inner_type)`

  ## Special Types

    * Custom modules → `Module.t()` (for loaded Elixir modules)

  ## Examples

      iex> to_elixir_type(:string)
      {:__block__, [], [{:., [], [String, :t]}, []]}

      iex> to_elixir_type({:array, :string})
      {:list, [], [{:., [], [String, :t]}, []]}

      iex> to_elixir_type({:map, :integer})
      {:%{}, [], [{:=>, [], [term(), {:integer, [], []}]}]}

      iex> to_elixir_type(MyCustomType)
      {:., [], [MyCustomType, :t]}, []

  ## Parameters

    * `ecto_type` - The Ecto field type to convert

  ## Returns

  A quoted expression representing the Elixir type specification.

  ## Errors

  Raises `ArgumentError` for unsupported types.
  """
  @spec to_elixir_type(ecto_type(), keyword()) :: Macro.t()
  def to_elixir_type(ecto_type, opts \\ []) do
    {type_opts, typed} = Keyword.split(opts, [:type])

    # If we have a custom type, return it directly without further processing
    case Keyword.fetch(type_opts, :type) do
      {:ok, type} ->
        type

      :error ->
        base_type =
          case ecto_type do
            :any ->
              quote do: term()

            :string ->
              quote do: String.t()

            :integer ->
              quote do: integer()

            :float ->
              quote do: float()

            :boolean ->
              quote do: boolean()

            :binary ->
              quote do: binary()

            :bitstring ->
              quote do: bitstring()

            :decimal ->
              quote do: Decimal.t()

            :date ->
              quote do: Date.t()

            :time ->
              quote do: Time.t()

            :time_usec ->
              quote do: Time.t()

            :naive_datetime ->
              quote do: NaiveDateTime.t()

            :naive_datetime_usec ->
              quote do: NaiveDateTime.t()

            :utc_datetime ->
              quote do: DateTime.t()

            :utc_datetime_usec ->
              quote do: DateTime.t()

            :duration ->
              quote do: Duration.t()

            :binary_id ->
              quote do: Ecto.UUID.t()

            :map ->
              quote do: map()

            {:map, inner_type} ->
              inner_elixir_type = to_elixir_type(inner_type)
              quote do: %{term() => unquote(inner_elixir_type)}

            :array ->
              quote do: list()

            {:array, inner_type} ->
              inner_elixir_type = to_elixir_type(inner_type)
              quote do: list(unquote(inner_elixir_type))

            :id ->
              quote do: integer()

            {:assoc, %Ecto.Association.BelongsTo{related: related}} ->
              quote do: Ecto.Schema.belongs_to(unquote(related).t())

            {:assoc, %Ecto.Association.Has{related: related, cardinality: :one}} ->
              quote do: Ecto.Schema.has_one(unquote(related).t())

            {:assoc, %Ecto.Association.Has{related: related, cardinality: :many}} ->
              quote do: Ecto.Schema.has_many(unquote(related).t())

            {:assoc, %Ecto.Association.ManyToMany{related: related}} ->
              quote do: Ecto.Schema.many_to_many(unquote(related).t())

            # Embed fields (embeds_one)
            {:embed, %{related: related, cardinality: :one}} ->
              quote do: Ecto.Schema.embeds_one(unquote(related).t())

            # Embed fields (embeds_many)
            {:embed, %{related: related, cardinality: :many}} ->
              quote do: Ecto.Schema.embeds_many(unquote(related).t())

            # Parameterized types (e.g., Ecto.Enum) - handle both old and new Ecto formats
            {:parameterized, {Ecto.Enum, params}} ->
              handle_ecto_enum(typed, params)

            {:parameterized, Ecto.Enum, params} ->
              handle_ecto_enum(typed, params)

            {:parameterized, Ecto.Enum} ->
              handle_ecto_enum(typed, nil)

            {:parameterized, {module, _params}} when is_atom(module) ->
              # For other parameterized types with params (new format)
              quote do: unquote(module).t()

            {:parameterized, module} when is_atom(module) ->
              # For other parameterized types, try to use the module's type
              quote do: unquote(module).t()

            {:parameterized, module, _params} when is_atom(module) ->
              # For other parameterized types with params (old format)
              quote do: unquote(module).t()

            # Special handling for Ecto.UUID
            Ecto.UUID ->
              quote do: Ecto.UUID.t()

            # Custom module types
            module when is_atom(module) and not is_nil(module) ->
              module_string = Atom.to_string(module)

              case module_string do
                "Elixir." <> _ ->
                  quote do: unquote(module).t()

                _ ->
                  raise ArgumentError, "Unsupported non-Elixir module type: #{inspect(module)}"
              end

            other ->
              raise ArgumentError, "Unsupported Ecto type: #{inspect(other)}"
          end

        # Return the base type without adding | nil
        # TypedStructor will handle adding | nil based on the field options
        base_type
    end
  end

  defp handle_ecto_enum(typed, params) do
    case Keyword.get(typed, :enum_values) do
      values when is_list(values) and values != [] ->
        generate_enum_union(values)

      _ ->
        case extract_enum_values(params) do
          [] -> quote do: atom()
          values -> generate_enum_union(values)
        end
    end
  end

  defp extract_enum_values({:%{}, _meta, opts}) do
    # Extract values from the AST map representation
    case Keyword.get(opts, :values) do
      values when is_list(values) ->
        values

      _ ->
        # Try to get from mappings in AST format
        case Keyword.get(opts, :mappings) do
          mappings when is_list(mappings) ->
            Keyword.keys(mappings)

          _ ->
            []
        end
    end
  end

  defp extract_enum_values(%{values: values}) when is_list(values) do
    values
  end

  defp extract_enum_values(%{mappings: mappings}) when is_list(mappings) do
    # Extract the atom keys from the mappings
    Keyword.keys(mappings)
  end

  defp extract_enum_values(_), do: []

  defp generate_enum_union([single_value]) do
    # Single value doesn't need a union
    single_value
  end

  defp generate_enum_union(values) do
    # Generate proper union type: :a | :b | :c
    values
    |> Enum.reverse()
    |> Enum.reduce(fn val, acc ->
      {:|, [], [val, acc]}
    end)
  end
end
