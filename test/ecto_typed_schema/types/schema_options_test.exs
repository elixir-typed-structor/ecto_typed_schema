defmodule EctoTypedSchema.Types.SchemaOptionsTest do
  use TypeTestCase, async: true

  @compile {:no_warn_undefined, __MODULE__.Schema}

  describe "schema-level null: false" do
    test "applies to all fields", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "test" do
            field :name, :string
            field :age, :integer
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  name: String.t(),
                  age: integer()
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "test", null: false do
            field :name, :string
            field :age, :integer
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "field-level typed overrides schema-level options" do
    test "field null: true overrides schema null: false", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "test" do
            field :name, :string
            field :optional_field, :string
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  name: String.t(),
                  optional_field: String.t() | nil
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "test", null: false do
            field :name, :string
            field :optional_field, :string, typed: [null: true]
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "primary key is always non-nullable" do
    test "without schema-level options", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "test" do
            field :name, :string
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  name: String.t() | nil
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "test" do
            field :name, :string
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end

    test "with schema-level null: false", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "test" do
            field :name, :string
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  name: String.t()
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "test", null: false do
            field :name, :string
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "schema-level options with custom primary key" do
    test "null: false with binary_id primary key", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          @primary_key {:uuid, :binary_id, autogenerate: true}

          schema "test" do
            field :name, :string
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  uuid: Ecto.UUID.t(),
                  name: String.t()
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          @primary_key {:uuid, :binary_id, autogenerate: true}

          typed_schema "test", null: false do
            field :name, :string
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "type_kind: :opaque on embedded schema" do
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

  describe "custom @primary_key on regular schema" do
    test "binary_id primary key type", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          @primary_key {:id, :binary_id, read_after_writes: true}

          schema "test" do
            field :name, :string
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: Ecto.UUID.t(),
                  name: String.t() | nil
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          @primary_key {:id, :binary_id, read_after_writes: true}

          typed_schema "test" do
            field :name, :string
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end
end
