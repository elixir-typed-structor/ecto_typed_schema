defmodule EctoTypedSchema.TypeMapper do
  @moduledoc """
  Maps Ecto schema field types to Elixir typespec AST.

  Given an Ecto type (e.g. `:string`, `{:array, :integer}`,
  `{:assoc, %Ecto.Association.Has{...}}`), this module produces the
  corresponding quoted Elixir type for use in `@type` definitions.
  """

  @typedoc "Ecto types accepted by `to_elixir_type/2`."
  @type ecto_type ::
          atom()
          | {:array, atom()}
          | {:map, atom()}
          | {:assoc, Ecto.Association.t()}
          | {:embed, map()}
          | {:parameterized, {module(), term()}}
          | {:parameterized, module()}
          | {:parameterized, module(), term()}

  @doc """
  Converts an Ecto field type into a quoted Elixir typespec.

  ## Recognised options

    * `:type` - When present, returned as-is (user-supplied type override).
    * `:enum_values` - List of atoms for `Ecto.Enum` fields; produces a
      union type (e.g. `:active | :inactive`).

  All other keys in `opts` are ignored by this function but may be
  passed through for convenience.

  ## Supported Ecto types

  See the module documentation for the full mapping table.

  ### Basic types

    * `:string` -> `String.t()`
    * `:integer` -> `integer()`
    * `:float` -> `float()`
    * `:boolean` -> `boolean()`
    * `:binary` -> `binary()`
    * `:bitstring` -> `bitstring()`
    * `:decimal` -> `Decimal.t()`
    * `:id` -> `integer()`
    * `:binary_id` -> `Ecto.UUID.t()`
    * `:map` -> `map()`
    * `:array` -> `list()`

  ### Temporal types

    * `:date` -> `Date.t()`
    * `:time` / `:time_usec` -> `Time.t()`
    * `:naive_datetime` / `:naive_datetime_usec` -> `NaiveDateTime.t()`
    * `:datetime` / `:utc_datetime` / `:utc_datetime_usec` -> `DateTime.t()`
    * `:duration` -> `Duration.t()`

  ### Composite types

    * `{:map, inner}` -> `%{term() => inner_type}`
    * `{:array, inner}` -> `list(inner_type)`

  ### Association / embed types

    * `{:assoc, %Ecto.Association.BelongsTo{}}` -> `Ecto.Schema.belongs_to(Schema.t())`
    * `{:assoc, %Ecto.Association.Has{cardinality: :one}}` -> `Ecto.Schema.has_one(Schema.t())`
    * `{:assoc, %Ecto.Association.Has{cardinality: :many}}` -> `Ecto.Schema.has_many(Schema.t())`
    * `{:assoc, %Ecto.Association.ManyToMany{}}` -> `Ecto.Schema.many_to_many(Schema.t())`
    * `{:embed, %{cardinality: :one}}` -> `Ecto.Schema.embeds_one(Schema.t())`
    * `{:embed, %{cardinality: :many}}` -> `Ecto.Schema.embeds_many(Schema.t())`

  ### Parameterized types

    * `Ecto.Enum` -> union of atom values or `atom()`
    * Other parameterized modules -> `Module.t()`

  ### Custom modules

    * Any Elixir module -> `Module.t()`

  ## Returns

  A quoted expression representing the Elixir typespec.

  Raises `ArgumentError` for unsupported types.
  """
  @spec to_elixir_type(ecto_type(), keyword()) :: Macro.t()
  def to_elixir_type(ecto_type, opts \\ []) do
    {type_opts, typed} = Keyword.split(opts, [:type])

    # If a custom type override is provided, return it directly.
    case Keyword.fetch(type_opts, :type) do
      {:ok, type} ->
        type

      :error ->
        map_ecto_type(ecto_type, typed)
    end
  end

  # Lookup table for primitive Ecto types to their quoted Elixir typespecs.
  @primitive_types %{
    any: quote(do: term()),
    string: quote(do: String.t()),
    integer: quote(do: integer()),
    float: quote(do: float()),
    boolean: quote(do: boolean()),
    binary: quote(do: binary()),
    bitstring: quote(do: bitstring()),
    decimal: quote(do: Decimal.t()),
    date: quote(do: Date.t()),
    time: quote(do: Time.t()),
    time_usec: quote(do: Time.t()),
    naive_datetime: quote(do: NaiveDateTime.t()),
    naive_datetime_usec: quote(do: NaiveDateTime.t()),
    utc_datetime: quote(do: DateTime.t()),
    utc_datetime_usec: quote(do: DateTime.t()),
    duration: quote(do: Duration.t()),
    binary_id: quote(do: Ecto.UUID.t()),
    map: quote(do: map()),
    array: quote(do: list()),
    id: quote(do: integer())
  }

  @spec map_ecto_type(ecto_type(), keyword()) :: Macro.t()
  defp map_ecto_type(ecto_type, _typed) when is_atom(ecto_type) do
    case Map.fetch(@primitive_types, ecto_type) do
      {:ok, type_ast} -> type_ast
      :error -> map_module_type(ecto_type)
    end
  end

  defp map_ecto_type({:map, inner}, _typed),
    do: quote(do: %{term() => unquote(to_elixir_type(inner))})

  defp map_ecto_type({:array, inner}, _typed),
    do: quote(do: list(unquote(to_elixir_type(inner))))

  defp map_ecto_type({:assoc, assoc}, _typed), do: map_assoc_type(assoc)
  defp map_ecto_type({:embed, embed}, _typed), do: map_embed_type(embed)

  defp map_ecto_type({:parameterized, _, _} = param, typed),
    do: map_parameterized_type(param, typed)

  defp map_ecto_type({:parameterized, _} = param, typed), do: map_parameterized_type(param, typed)

  defp map_ecto_type(other, _typed),
    do: raise(ArgumentError, "Unsupported Ecto type: #{inspect(other)}")

  @spec map_assoc_type(Ecto.Association.t()) :: Macro.t()
  defp map_assoc_type(%Ecto.Association.BelongsTo{related: r}),
    do: quote(do: Ecto.Schema.belongs_to(unquote(r).t()))

  defp map_assoc_type(%Ecto.Association.Has{related: r, cardinality: :one}),
    do: quote(do: Ecto.Schema.has_one(unquote(r).t()))

  defp map_assoc_type(%Ecto.Association.Has{related: r, cardinality: :many}),
    do: quote(do: Ecto.Schema.has_many(unquote(r).t()))

  defp map_assoc_type(%Ecto.Association.ManyToMany{related: r}),
    do: quote(do: Ecto.Schema.many_to_many(unquote(r).t()))

  @spec map_embed_type(map()) :: Macro.t()
  defp map_embed_type(%{related: r, cardinality: :one}),
    do: quote(do: Ecto.Schema.embeds_one(unquote(r).t()))

  defp map_embed_type(%{related: r, cardinality: :many}),
    do: quote(do: Ecto.Schema.embeds_many(unquote(r).t()))

  @spec map_parameterized_type(ecto_type(), keyword()) :: Macro.t()
  defp map_parameterized_type({:parameterized, {Ecto.Enum, params}}, typed),
    do: handle_ecto_enum(typed, params)

  defp map_parameterized_type({:parameterized, Ecto.Enum, params}, typed),
    do: handle_ecto_enum(typed, params)

  defp map_parameterized_type({:parameterized, Ecto.Enum}, typed),
    do: handle_ecto_enum(typed, nil)

  defp map_parameterized_type({:parameterized, {mod, _}}, _typed) when is_atom(mod),
    do: quote(do: unquote(mod).t())

  defp map_parameterized_type({:parameterized, mod}, _typed) when is_atom(mod),
    do: quote(do: unquote(mod).t())

  defp map_parameterized_type({:parameterized, mod, _}, _typed) when is_atom(mod),
    do: quote(do: unquote(mod).t())

  @spec map_module_type(module()) :: Macro.t()
  defp map_module_type(Ecto.UUID), do: quote(do: Ecto.UUID.t())

  defp map_module_type(nil),
    do: raise(ArgumentError, "Unsupported Ecto type: nil")

  defp map_module_type(mod) do
    case Atom.to_string(mod) do
      "Elixir." <> _ -> quote(do: unquote(mod).t())
      _ -> raise ArgumentError, "Unsupported non-Elixir module type: #{inspect(mod)}"
    end
  end

  @spec handle_ecto_enum(keyword(), term()) :: Macro.t()
  defp handle_ecto_enum(typed, params) do
    case Keyword.get(typed, :enum_values) do
      values when is_list(values) and values != [] ->
        generate_enum_union(values)

      _ ->
        case extract_enum_values(params) do
          [] -> quote(do: atom())
          values -> generate_enum_union(values)
        end
    end
  end

  @spec extract_enum_values(term()) :: [atom()]
  defp extract_enum_values({:%{}, _meta, opts}) do
    case Keyword.get(opts, :values) do
      values when is_list(values) ->
        values

      _ ->
        case Keyword.get(opts, :mappings) do
          mappings when is_list(mappings) -> Keyword.keys(mappings)
          _ -> []
        end
    end
  end

  defp extract_enum_values(%{values: values}) when is_list(values), do: values

  defp extract_enum_values(%{mappings: mappings}) when is_list(mappings) do
    Keyword.keys(mappings)
  end

  defp extract_enum_values(_), do: []

  @spec generate_enum_union([atom(), ...]) :: Macro.t()
  defp generate_enum_union([single_value]), do: single_value

  defp generate_enum_union(values) do
    values
    |> Enum.reverse()
    |> Enum.reduce(fn val, acc -> {:|, [], [val, acc]} end)
  end
end
