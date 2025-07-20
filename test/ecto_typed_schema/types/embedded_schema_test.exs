defmodule EctoTypedSchema.Types.EmbeddedSchemaTest do
  use TypeTestCase, async: true

  @compile {:no_warn_undefined, __MODULE__.Schema}

  describe "generates type without __meta__" do
    test "embedded schema has no __meta__ field", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          embedded_schema do
            field :name, :string
            field :age, :integer
          end

          @type t() :: %__MODULE__{
                  id: Ecto.UUID.t(),
                  name: String.t() | nil,
                  age: integer() | nil
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_embedded_schema do
            field :name, :string
            field :age, :integer
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "with schema-level enforce: true" do
    test "all fields are non-nullable", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          embedded_schema do
            field :name, :string
            field :age, :integer
          end

          @type t() :: %__MODULE__{
                  id: Ecto.UUID.t(),
                  name: String.t(),
                  age: integer()
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_embedded_schema enforce: true do
            field :name, :string
            field :age, :integer
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "with schema-level null: false" do
    test "all fields are non-nullable", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          embedded_schema do
            field :name, :string
            field :age, :integer
          end

          @type t() :: %__MODULE__{
                  id: Ecto.UUID.t(),
                  name: String.t(),
                  age: integer()
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_embedded_schema null: false do
            field :name, :string
            field :age, :integer
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "field-level override of schema options" do
    test "field null: true overrides schema null: false", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          embedded_schema do
            field :name, :string
            field :optional, :string
          end

          @type t() :: %__MODULE__{
                  id: Ecto.UUID.t(),
                  name: String.t(),
                  optional: String.t() | nil
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_embedded_schema null: false do
            field :name, :string
            field :optional, :string, typed: [null: true]
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "default primary key is binary_id" do
    test "id field maps to Ecto.UUID.t() for embedded schema", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          embedded_schema do
            field :name, :string
          end

          @type t() :: %__MODULE__{
                  id: Ecto.UUID.t(),
                  name: String.t() | nil
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_embedded_schema do
            field :name, :string
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "no primary key" do
    test "embedded schema with @primary_key false", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          @primary_key false

          embedded_schema do
            field :name, :string
          end

          @type t() :: %__MODULE__{
                  name: String.t() | nil
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          @primary_key false

          typed_embedded_schema do
            field :name, :string
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "custom primary key" do
    test "embedded schema with custom string primary key", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          @primary_key {:key, :string, autogenerate: false}

          embedded_schema do
            field :name, :string
          end

          @type t() :: %__MODULE__{
                  key: String.t(),
                  name: String.t() | nil
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          @primary_key {:key, :string, autogenerate: false}

          typed_embedded_schema do
            field :name, :string
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "nested embeds inside embedded schema" do
    defmodule InnerEmbed do
      use Ecto.Schema

      @type t() :: %__MODULE__{}

      embedded_schema do
        field :value, :string
      end
    end

    test "embedded schema with embeds_one", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          embedded_schema do
            field :name, :string
            embeds_one :inner, InnerEmbed
          end

          @type t() :: %__MODULE__{
                  id: Ecto.UUID.t(),
                  name: String.t() | nil,
                  inner: Ecto.Schema.embeds_one(InnerEmbed.t()) | nil
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_embedded_schema do
            field :name, :string
            embeds_one :inner, InnerEmbed
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end

    test "embedded schema with embeds_many", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          embedded_schema do
            field :name, :string
            embeds_many :items, InnerEmbed
          end

          @type t() :: %__MODULE__{
                  id: Ecto.UUID.t(),
                  name: String.t() | nil,
                  items: Ecto.Schema.embeds_many(InnerEmbed.t())
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_embedded_schema do
            field :name, :string
            embeds_many :items, InnerEmbed
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "combined schema-level options" do
    test "enforce: true and null: false together", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          embedded_schema do
            field :name, :string
            field :age, :integer
          end

          @type t() :: %__MODULE__{
                  id: Ecto.UUID.t(),
                  name: String.t(),
                  age: integer()
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_embedded_schema enforce: true, null: false do
            field :name, :string
            field :age, :integer
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end
end
