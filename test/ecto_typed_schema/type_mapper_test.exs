defmodule EctoTypedSchema.TypeMapperTest do
  use ExUnit.Case, async: true
  alias EctoTypedSchema.TypeMapper

  describe "to_elixir_type/1 - Official Ecto Primitive Types" do
    test "ID types" do
      assert infer_type_string(:id) == "integer()"
      assert infer_type_string(:binary_id) == "Ecto.UUID.t()"
    end

    test "basic types" do
      assert infer_type_string(:integer) == "integer()"
      assert infer_type_string(:float) == "float()"
      assert infer_type_string(:boolean) == "boolean()"
      assert infer_type_string(:string) == "String.t()"
      assert infer_type_string(:binary) == "binary()"
      assert infer_type_string(:bitstring) == "bitstring()"
    end

    test "array types with inner types" do
      # Test {:array, inner_type} with representative examples
      assert infer_type_string({:array, :string}) == "list(String.t())"
      assert infer_type_string({:array, :integer}) == "list(integer())"
      assert infer_type_string({:array, :decimal}) == "list(Decimal.t())"
    end

    test "map types" do
      # Basic map
      assert infer_type_string(:map) == "map()"

      # Map with inner types - representative examples
      assert infer_type_string({:map, :string}) == "%{term() => String.t()}"
      assert infer_type_string({:map, :integer}) == "%{term() => integer()}"
      assert infer_type_string({:map, :decimal}) == "%{term() => Decimal.t()}"
    end

    test "special types" do
      assert infer_type_string(:decimal) == "Decimal.t()"
    end

    test "temporal types" do
      assert infer_type_string(:date) == "Date.t()"
      assert infer_type_string(:time) == "Time.t()"
      assert infer_type_string(:time_usec) == "Time.t()"
      assert infer_type_string(:naive_datetime) == "NaiveDateTime.t()"
      assert infer_type_string(:naive_datetime_usec) == "NaiveDateTime.t()"
      assert infer_type_string(:utc_datetime) == "DateTime.t()"
      assert infer_type_string(:utc_datetime_usec) == "DateTime.t()"
      assert infer_type_string(:duration) == "Duration.t()"
    end

    test "nested complex types" do
      # Nested arrays
      assert infer_type_string({:array, {:array, :string}}) == "list(list(String.t()))"

      # Nested maps
      assert infer_type_string({:map, {:map, :string}}) == "%{term() => %{term() => String.t()}}"

      # Array of maps
      assert infer_type_string({:array, {:map, :string}}) == "list(%{term() => String.t()})"

      # Map with array values
      assert infer_type_string({:map, {:array, :integer}}) == "%{term() => list(integer())}"

      # Test deeply nested structures
      assert infer_type_string({:array, {:array, {:map, :string}}}) ==
               "list(list(%{term() => String.t()}))"

      assert infer_type_string({:map, {:array, {:map, :integer}}}) ==
               "%{term() => list(%{term() => integer()})}"
    end
  end

  describe "to_elixir_type/1 - custom types and error handling" do
    test "infers Ecto.UUID type correctly" do
      assert infer_type_string(Ecto.UUID) == "Ecto.UUID.t()"
    end

    test "infers custom module types correctly" do
      assert infer_type_string(MyApp.User) == "MyApp.User.t()"
    end

    test "raises errors for unsupported types" do
      # Invalid compound type
      assert_raise ArgumentError, ~r/Unsupported Ecto type/, fn ->
        TypeMapper.to_elixir_type({:unknown, :compound, :type})
      end

      # Nil input
      assert_raise ArgumentError, ~r/Unsupported Ecto type/, fn ->
        TypeMapper.to_elixir_type(nil)
      end
    end

    test "raises error for non-Elixir atoms" do
      # Unknown primitive type (non-Elixir atom)
      assert_raise ArgumentError, ~r/Unsupported non-Elixir module type/, fn ->
        TypeMapper.to_elixir_type(:unknown_type)
      end

      # Erlang atom that's not a module
      assert_raise ArgumentError, ~r/Unsupported non-Elixir module type/, fn ->
        TypeMapper.to_elixir_type(:some_erlang_module)
      end
    end
  end

  describe "to_elixir_type/2 - custom type override" do
    test "returns custom type when :type option is provided" do
      custom = quote(do: MyApp.Status.t())
      assert TypeMapper.to_elixir_type(:string, type: custom) == custom
    end
  end

  describe "to_elixir_type/1 - :any type" do
    test "maps :any to term()" do
      assert infer_type_string(:any) == "term()"
    end
  end

  describe "to_elixir_type/1 - bare :array type" do
    test "maps :array to list()" do
      assert infer_type_string(:array) == "list()"
    end
  end

  describe "to_elixir_type/1 - association types" do
    test "belongs_to" do
      assoc = %Ecto.Association.BelongsTo{
        field: :user,
        owner: MyApp.Post,
        related: MyApp.User,
        owner_key: :user_id,
        related_key: :id,
        queryable: MyApp.User,
        cardinality: :one,
        relationship: :parent,
        on_replace: :raise,
        defaults: [],
        on_cast: nil,
        where: [],
        unique: true,
        ordered: false
      }

      assert infer_type_string({:assoc, assoc}) ==
               "Ecto.Schema.belongs_to(MyApp.User.t())"
    end

    test "has_one" do
      assoc = %Ecto.Association.Has{
        field: :profile,
        owner: MyApp.User,
        related: MyApp.Profile,
        owner_key: :id,
        related_key: :user_id,
        queryable: MyApp.Profile,
        cardinality: :one,
        relationship: :child,
        on_delete: :nothing,
        on_replace: :raise,
        defaults: [],
        where: [],
        unique: true,
        ordered: false,
        preload_order: []
      }

      assert infer_type_string({:assoc, assoc}) ==
               "Ecto.Schema.has_one(MyApp.Profile.t())"
    end

    test "has_many" do
      assoc = %Ecto.Association.Has{
        field: :posts,
        owner: MyApp.User,
        related: MyApp.Post,
        owner_key: :id,
        related_key: :user_id,
        queryable: MyApp.Post,
        cardinality: :many,
        relationship: :child,
        on_delete: :nothing,
        on_replace: :raise,
        defaults: [],
        where: [],
        unique: true,
        ordered: false,
        preload_order: []
      }

      assert infer_type_string({:assoc, assoc}) ==
               "Ecto.Schema.has_many(MyApp.Post.t())"
    end

    test "many_to_many" do
      assoc = %Ecto.Association.ManyToMany{
        field: :tags,
        owner: MyApp.Post,
        related: MyApp.Tag,
        owner_key: :id,
        queryable: MyApp.Tag,
        cardinality: :many,
        relationship: :child,
        on_delete: :nothing,
        on_replace: :raise,
        defaults: [],
        join_keys: [{:post_id, :id}, {:tag_id, :id}],
        join_through: "posts_tags",
        join_where: [],
        join_defaults: [],
        where: [],
        unique: false,
        ordered: false,
        preload_order: []
      }

      assert infer_type_string({:assoc, assoc}) ==
               "Ecto.Schema.many_to_many(MyApp.Tag.t())"
    end
  end

  describe "to_elixir_type/1 - embed types" do
    test "embeds_one" do
      embed = %{related: MyApp.Address, cardinality: :one}

      assert infer_type_string({:embed, embed}) ==
               "Ecto.Schema.embeds_one(MyApp.Address.t())"
    end

    test "embeds_many" do
      embed = %{related: MyApp.Address, cardinality: :many}

      assert infer_type_string({:embed, embed}) ==
               "Ecto.Schema.embeds_many(MyApp.Address.t())"
    end
  end

  describe "to_elixir_type/1 - parameterized types" do
    test "{:parameterized, {Ecto.Enum, params}} with enum_values typed opt" do
      params = %{values: [:active, :inactive]}

      result =
        {:parameterized, {Ecto.Enum, params}}
        |> TypeMapper.to_elixir_type(enum_values: [:on, :off])
        |> Macro.to_string()

      assert result == ":on | :off"
    end

    test "{:parameterized, Ecto.Enum, params} 3-tuple form" do
      params = %{values: [:active, :inactive]}

      result =
        {:parameterized, Ecto.Enum, params}
        |> TypeMapper.to_elixir_type([])
        |> Macro.to_string()

      assert result == ":active | :inactive"
    end

    test "{:parameterized, Ecto.Enum} bare form falls back to atom()" do
      result =
        {:parameterized, Ecto.Enum}
        |> TypeMapper.to_elixir_type([])
        |> Macro.to_string()

      assert result == "atom()"
    end

    test "{:parameterized, {CustomModule, _}} non-Enum" do
      result =
        {:parameterized, {MyApp.Money, %{}}}
        |> TypeMapper.to_elixir_type([])
        |> Macro.to_string()

      assert result == "MyApp.Money.t()"
    end

    test "{:parameterized, CustomModule} bare module" do
      result =
        {:parameterized, MyApp.Money}
        |> TypeMapper.to_elixir_type([])
        |> Macro.to_string()

      assert result == "MyApp.Money.t()"
    end

    test "{:parameterized, CustomModule, _} 3-tuple non-Enum" do
      result =
        {:parameterized, MyApp.Money, %{}}
        |> TypeMapper.to_elixir_type([])
        |> Macro.to_string()

      assert result == "MyApp.Money.t()"
    end
  end

  describe "to_elixir_type/1 - enum value extraction" do
    test "extracts values from %{values: [...]}" do
      params = %{values: [:draft, :published]}

      result =
        {:parameterized, {Ecto.Enum, params}}
        |> TypeMapper.to_elixir_type([])
        |> Macro.to_string()

      assert result == ":draft | :published"
    end

    test "extracts keys from %{mappings: [...]}" do
      params = %{mappings: [admin: "ADMIN", user: "USER"]}

      result =
        {:parameterized, {Ecto.Enum, params}}
        |> TypeMapper.to_elixir_type([])
        |> Macro.to_string()

      assert result == ":admin | :user"
    end

    test "falls back to atom() when params have no values or mappings" do
      params = %{something_else: true}

      result =
        {:parameterized, {Ecto.Enum, params}}
        |> TypeMapper.to_elixir_type([])
        |> Macro.to_string()

      assert result == "atom()"
    end

    test "single enum value" do
      params = %{values: [:only_one]}

      result =
        {:parameterized, {Ecto.Enum, params}}
        |> TypeMapper.to_elixir_type([])
        |> Macro.to_string()

      assert result == ":only_one"
    end

    test "extracts values from AST map with :values key" do
      params = {:%{}, [], [values: [:a, :b]]}

      result =
        {:parameterized, {Ecto.Enum, params}}
        |> TypeMapper.to_elixir_type([])
        |> Macro.to_string()

      assert result == ":a | :b"
    end

    test "extracts keys from AST map with :mappings key" do
      params = {:%{}, [], [mappings: [x: "X", y: "Y"]]}

      result =
        {:parameterized, {Ecto.Enum, params}}
        |> TypeMapper.to_elixir_type([])
        |> Macro.to_string()

      assert result == ":x | :y"
    end

    test "AST map with neither values nor mappings falls back to atom()" do
      params = {:%{}, [], [other: true]}

      result =
        {:parameterized, {Ecto.Enum, params}}
        |> TypeMapper.to_elixir_type([])
        |> Macro.to_string()

      assert result == "atom()"
    end
  end

  defp infer_type_string(ecto_type) do
    ecto_type
    |> TypeMapper.to_elixir_type()
    |> Macro.to_string()
  end
end
