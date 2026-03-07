defmodule EctoTypedSchema.Types.TimestampsTest do
  use TypeTestCase, async: true

  @compile {:no_warn_undefined, __MODULE__.Schema}

  describe "default timestamps :naive_datetime" do
    test "generates NaiveDateTime types for both fields", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "test" do
            field :name, :string
            timestamps()
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  name: String.t() | nil,
                  inserted_at: NaiveDateTime.t() | nil,
                  updated_at: NaiveDateTime.t() | nil
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "test" do
            field :name, :string
            timestamps()
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "with type: :utc_datetime" do
    test "generates DateTime types", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "test" do
            timestamps(type: :utc_datetime)
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  inserted_at: DateTime.t() | nil,
                  updated_at: DateTime.t() | nil
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "test" do
            timestamps(type: :utc_datetime)
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "with type: :utc_datetime_usec" do
    test "generates DateTime types", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "test" do
            timestamps(type: :utc_datetime_usec)
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  inserted_at: DateTime.t() | nil,
                  updated_at: DateTime.t() | nil
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "test" do
            timestamps(type: :utc_datetime_usec)
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "with custom field names" do
    test "uses custom inserted_at and updated_at names", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "test" do
            timestamps(inserted_at: :created_at, updated_at: :modified_at)
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  created_at: NaiveDateTime.t() | nil,
                  modified_at: NaiveDateTime.t() | nil
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "test" do
            timestamps(inserted_at: :created_at, updated_at: :modified_at)
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "disable inserted_at" do
    test "only generates updated_at", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "test" do
            timestamps(inserted_at: false)
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  updated_at: NaiveDateTime.t() | nil
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "test" do
            timestamps(inserted_at: false)
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "disable updated_at" do
    test "only generates inserted_at", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "test" do
            timestamps(updated_at: false)
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  inserted_at: NaiveDateTime.t() | nil
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "test" do
            timestamps(updated_at: false)
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "with @timestamps_opts" do
    test "pre-configured type and field names", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          @timestamps_opts [
            type: :utc_datetime,
            inserted_at: :created_at,
            updated_at: :modified_at
          ]

          schema "test" do
            field :name, :string
            timestamps()
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  name: String.t() | nil,
                  created_at: DateTime.t() | nil,
                  modified_at: DateTime.t() | nil
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          @timestamps_opts [
            type: :utc_datetime,
            inserted_at: :created_at,
            updated_at: :modified_at
          ]

          typed_schema "test" do
            field :name, :string
            timestamps()
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "with schema-level null: false" do
    test "timestamps become non-nullable", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "test" do
            field :name, :string
            timestamps()
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  name: String.t(),
                  inserted_at: NaiveDateTime.t(),
                  updated_at: NaiveDateTime.t()
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "test", null: false do
            field :name, :string
            timestamps()
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "in embedded_schema" do
    test "timestamps work inside typed_embedded_schema", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          embedded_schema do
            field :name, :string
            timestamps()
          end

          @type t() :: %__MODULE__{
                  id: Ecto.UUID.t(),
                  name: String.t() | nil,
                  inserted_at: NaiveDateTime.t() | nil,
                  updated_at: NaiveDateTime.t() | nil
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_embedded_schema do
            field :name, :string
            timestamps()
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "with typed: [null: false]" do
    test "generates non-nullable timestamp types", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "test" do
            timestamps()
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  inserted_at: NaiveDateTime.t(),
                  updated_at: NaiveDateTime.t()
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "test" do
            timestamps(typed: [null: false])
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end
end
