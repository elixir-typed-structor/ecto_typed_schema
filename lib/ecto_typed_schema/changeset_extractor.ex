defmodule EctoTypedSchema.ChangesetExtractor do
  @moduledoc """
  Extracts field names and their Ecto types from the AST of Ecto's
  generated `__changeset__/0` function body.

  The `__changeset__/0` function is defined by `Ecto.Schema` and returns
  a map of `%{field_name => ecto_type}`. This module parses that AST at
  compile time so `EctoTypedSchema` can map each field to an Elixir typespec.
  """

  @typep field_entry() ::
           {atom(),
            atom()
            | Ecto.Type.primitive()
            | {:parameterized, {module(), Ecto.ParameterizedType.params()}}
            | {:assoc, Ecto.Association.t()}
            | {:embed, map()}}

  @doc """
  Extracts a keyword list of `{field_name, ecto_type}` pairs from the
  AST of `__changeset__/0`.

  ## Parameters

    * `body` - The function body AST captured via `@on_definition`.
      Expected shape: `[do: {:%{}, _meta, field_list}]`.

  ## Returns

  A list of `{atom(), ecto_type}` tuples.

  Raises `ArgumentError` if the AST shape is not recognized.
  """
  @spec extract(keyword()) :: [field_entry()]
  def extract(do: {:%{}, _meta, field_list}) do
    Enum.map(field_list, fn
      # Parameterized types (e.g., Ecto.Enum)
      {field_name, {:parameterized, {module, params}}}
      when is_atom(field_name) and is_atom(module) ->
        {field_name, {:parameterized, {module, params}}}

      # Association fields
      {field_name, {:assoc, {:%{}, _meta, assoc_args}}} when is_atom(field_name) ->
        {field_name, {:assoc, Map.new(assoc_args)}}

      # Embed fields
      {field_name, {:embed, {:%{}, _meta, embed_args}}} when is_atom(field_name) ->
        {field_name, {:embed, Map.new(embed_args)}}

      # Primitive types
      {field_name, field_type} when is_atom(field_name) ->
        {field_name, field_type}
    end)
  end

  def extract(body) do
    raise ArgumentError,
          "unexpected __changeset__/0 body shape: #{inspect(body)}"
  end
end
