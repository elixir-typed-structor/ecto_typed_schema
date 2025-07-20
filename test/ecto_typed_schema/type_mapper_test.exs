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

  defp infer_type_string(ecto_type) do
    ecto_type
    |> TypeMapper.to_elixir_type()
    |> Macro.to_string()
  end
end
