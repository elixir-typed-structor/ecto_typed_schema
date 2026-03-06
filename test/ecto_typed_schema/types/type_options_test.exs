defmodule EctoTypedSchema.Types.TypeOptionsTest do
  use TypeTestCase, async: true

  @compile {:no_warn_undefined, __MODULE__.Schema}

  describe "single parameter" do
    test "generates parameterized type", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "users" do
            field :name, :string
            field :age, :integer
          end

          @type t(age) :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  name: String.t() | nil,
                  age: age | nil
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "users" do
            parameter :age

            field :name, :string
            field :age, :integer, typed: [type: age]
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "multiple parameters" do
    test "preserves declaration order", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "users" do
            field :name, :string
            field :age, :integer
          end

          @type t(age, name) :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  name: name | nil,
                  age: age | nil
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "users" do
            parameter :age
            parameter :name

            field :name, :string, typed: [type: name]
            field :age, :integer, typed: [type: age]
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "parameter in embedded schema" do
    test "generates parameterized type without __meta__", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          @primary_key false

          embedded_schema do
            field :value, :string
          end

          @type t(value_type) :: %__MODULE__{
                  value: value_type | nil
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          @primary_key false

          typed_embedded_schema do
            parameter :value_type

            field :value, :string, typed: [type: value_type]
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "type_kind: :opaque" do
    test "generates @opaque instead of @type", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          @primary_key false

          embedded_schema do
            field :int, :integer
          end

          @opaque t() :: %__MODULE__{
                    int: integer() | nil
                  }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          @primary_key false

          typed_embedded_schema type_kind: :opaque do
            field :int, :integer
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "type_name" do
    test "generates custom type name", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          @primary_key false

          embedded_schema do
            field :value, :string
          end

          @type user() :: %__MODULE__{
                  value: String.t() | nil
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          @primary_key false

          typed_embedded_schema type_name: :user do
            field :value, :string
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "combined options" do
    test "type_kind + type_name + parameter + null: false", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          @primary_key false

          embedded_schema do
            field :ok, :string
            field :error, :string
          end

          @opaque result(ok, error) :: %__MODULE__{
                    ok: ok,
                    error: error
                  }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          @primary_key false

          typed_embedded_schema type_kind: :opaque, type_name: :result, null: false do
            parameter :ok
            parameter :error

            field :ok, :string, typed: [type: ok]
            field :error, :string, typed: [type: error]
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end
end
