defmodule EctoTypedSchema.Types.FieldTest do
  use TypeTestCase, async: true

  @compile {:no_warn_undefined, __MODULE__.Schema}

  describe "basic types" do
    test "string, integer, float, boolean, binary, bitstring", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "test" do
            field :a_string, :string
            field :an_integer, :integer
            field :a_float, :float
            field :a_boolean, :boolean
            field :a_binary, :binary
            field :a_bitstring, :bitstring
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  a_string: String.t() | nil,
                  an_integer: integer() | nil,
                  a_float: float() | nil,
                  a_boolean: boolean() | nil,
                  a_binary: binary() | nil,
                  a_bitstring: bitstring() | nil
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "test" do
            field :a_string, :string
            field :an_integer, :integer
            field :a_float, :float
            field :a_boolean, :boolean
            field :a_binary, :binary
            field :a_bitstring, :bitstring
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "id types" do
    test "id and binary_id", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "test" do
            field :an_id, :id
            field :a_binary_id, :binary_id
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  an_id: integer() | nil,
                  a_binary_id: Ecto.UUID.t() | nil
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "test" do
            field :an_id, :id
            field :a_binary_id, :binary_id
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "temporal types" do
    test "date, time, naive_datetime, utc_datetime, duration", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "test" do
            field :a_date, :date
            field :a_time, :time
            field :a_time_usec, :time_usec
            field :a_naive_datetime, :naive_datetime
            field :a_naive_datetime_usec, :naive_datetime_usec
            field :a_utc_datetime, :utc_datetime
            field :a_utc_datetime_usec, :utc_datetime_usec
            field :a_duration, :duration
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  a_date: Date.t() | nil,
                  a_time: Time.t() | nil,
                  a_time_usec: Time.t() | nil,
                  a_naive_datetime: NaiveDateTime.t() | nil,
                  a_naive_datetime_usec: NaiveDateTime.t() | nil,
                  a_utc_datetime: DateTime.t() | nil,
                  a_utc_datetime_usec: DateTime.t() | nil,
                  a_duration: Duration.t() | nil
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "test" do
            field :a_date, :date
            field :a_time, :time
            field :a_time_usec, :time_usec
            field :a_naive_datetime, :naive_datetime
            field :a_naive_datetime_usec, :naive_datetime_usec
            field :a_utc_datetime, :utc_datetime
            field :a_utc_datetime_usec, :utc_datetime_usec
            field :a_duration, :duration
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "decimal type" do
    test "decimal", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "test" do
            field :amount, :decimal
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  amount: Decimal.t() | nil
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "test" do
            field :amount, :decimal
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "map type" do
    test "map", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "test" do
            field :metadata, :map
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  metadata: map() | nil
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "test" do
            field :metadata, :map
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "custom module type" do
    test "Ecto.UUID as field type", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "test" do
            field :external_id, Ecto.UUID
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  external_id: Ecto.UUID.t() | nil
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "test" do
            field :external_id, Ecto.UUID
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "array composite type" do
    test "array of strings and array of integers", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "test" do
            field :tags, {:array, :string}
            field :scores, {:array, :integer}
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  tags: list(String.t()) | nil,
                  scores: list(integer()) | nil
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "test" do
            field :tags, {:array, :string}
            field :scores, {:array, :integer}
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "map composite type" do
    test "map with integer values", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "test" do
            field :counters, {:map, :integer}
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  counters: %{term() => integer()} | nil
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "test" do
            field :counters, {:map, :integer}
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "Ecto.Enum" do
    test "generates union type from values", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "test" do
            field :status, Ecto.Enum, values: [:active, :inactive]
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  status: (:active | :inactive) | nil
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "test" do
            field :status, Ecto.Enum, values: [:active, :inactive]
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end

    test "generates union type from mappings", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "test" do
            field :role, Ecto.Enum, values: [admin: "ADMIN", user: "USER"]
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  role: (:admin | :user) | nil
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "test" do
            field :role, Ecto.Enum, values: [admin: "ADMIN", user: "USER"]
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "custom type override via typed option" do
    test "overrides inferred type", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "test" do
            field :status, :string
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  status: (:active | :inactive) | nil
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "test" do
            field :status, :string, typed: [type: :active | :inactive]
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "custom type override with local typep" do
    test "uses local private type", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          @typep my_type() :: String.t()

          schema "test" do
            field :name, :string
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  name: my_type() | nil
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          @typep my_type() :: String.t()

          typed_schema "test" do
            field :name, :string, typed: [type: my_type()]
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "field with null: false" do
    test "removes nil from type", ctx do
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

          typed_schema "test" do
            field :name, :string, typed: [null: false]
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "field with default value" do
    test "non-nullable when default is set", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "test" do
            field :role, :string, default: "user"
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  role: String.t()
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "test" do
            field :role, :string, default: "user"
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "custom primary key :binary_id" do
    test "generates non-nullable primary key type", ctx do
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
                  name: String.t() | nil
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          @primary_key {:uuid, :binary_id, autogenerate: true}

          typed_schema "test" do
            field :name, :string
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "no primary key" do
    test "omits id field from type", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          @primary_key false

          schema "test" do
            field :name, :string
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  name: String.t() | nil
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          @primary_key false

          typed_schema "test" do
            field :name, :string
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "virtual field" do
    test "virtual field with :any type", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "test" do
            field :data, :any, virtual: true
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  data: term() | nil
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "test" do
            field :data, :any, virtual: true
          end
        after
          assert :data in Schema.__schema__(:virtual_fields)

          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end

    test "generates type for virtual fields", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "test" do
            field :name, :string
            field :computed, :string, virtual: true
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  name: String.t() | nil,
                  computed: String.t() | nil
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "test" do
            field :name, :string
            field :computed, :string, virtual: true
          end
        after
          assert :computed in Schema.__schema__(:virtual_fields)

          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "combined typed options" do
    test "custom type with null: false", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "test" do
            field :status, :string
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  status: :active | :inactive
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "test" do
            field :status, :string, typed: [type: :active | :inactive, null: false]
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "default with null override" do
    test "null: true keeps type nullable despite having a default", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "test" do
            field :role, :string, default: "user"
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  role: String.t() | nil
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "test" do
            field :role, :string, default: "user", typed: [null: true]
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "field with default: nil" do
    test "stays nullable despite having a default", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "test" do
            field :name, :string, default: nil
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
            field :name, :string, default: nil
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "nested composite types" do
    test "array of arrays", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "test" do
            field :matrix, {:array, {:array, :string}}
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  matrix: list(list(String.t())) | nil
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "test" do
            field :matrix, {:array, {:array, :string}}
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end
end
