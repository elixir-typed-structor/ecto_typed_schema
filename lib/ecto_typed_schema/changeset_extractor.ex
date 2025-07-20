defmodule EctoTypedSchema.ChangesetExtractor do
  @moduledoc """
  Module responsible for analyzing and extracting field information from
  Ecto's generated __changeset__/0 function.
  """

  @spec extract(Macro.t()) :: [
          {
            atom(),
            atom()
            | Ecto.Type.primitive()
            | {:parameterized, {module(), Ecto.ParameterizedType.params()}}
            | {:assoc, Ecto.Association.t()}
          }
        ]
  def extract(do: {:%{}, _meta, field_list}) do
    Enum.map(field_list, fn
      # Parameterized types (e.g., Ecto.Enum) 
      {field_name, {:parameterized, {module, params}}}
      when is_atom(field_name) and is_atom(module) ->
        {field_name, {:parameterized, {module, params}}}

      # Association fields
      {field_name, {:assoc, {:%{}, _meta, assoc_args}}} when is_atom(field_name) ->
        assoc = Map.new(assoc_args)

        {field_name, {:assoc, assoc}}

      # Embed fields
      {field_name, {:embed, {:%{}, _meta, embed_args}}} when is_atom(field_name) ->
        embed = Map.new(embed_args)

        {field_name, {:embed, embed}}

      # Primitive types
      {field_name, field_type} when is_atom(field_name) ->
        {field_name, field_type}
    end)
  end
end
