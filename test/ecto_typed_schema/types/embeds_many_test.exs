defmodule EctoTypedSchema.Types.EmbedsManyTest do
  use TypeTestCase, async: true

  @compile {:no_warn_undefined, __MODULE__.Schema}

  defmodule Address do
    use Ecto.Schema

    @type t() :: %__MODULE__{}

    embedded_schema do
      field :street, :string
      field :city, :string
    end
  end

  describe "basic embeds_many (non-nullable, defaults to [])" do
    test "generates list type without nil", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "users" do
            embeds_many :addresses, Address
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  addresses: Ecto.Schema.embeds_many(Address.t())
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "users" do
            embeds_many :addresses, Address
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "inline schema definition" do
    test "generates type referencing inline module", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "users" do
            embeds_many :addresses, InlineAddress, primary_key: false do
              Ecto.Schema.field(:street, :string)
              Ecto.Schema.field(:city, :string)
            end
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  addresses: Ecto.Schema.embeds_many(__MODULE__.InlineAddress.t())
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "users" do
            embeds_many :addresses, InlineAddress, primary_key: false do
              Ecto.Schema.field(:street, :string)
              Ecto.Schema.field(:city, :string)
            end
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "with schema-level null: false" do
    test "embeds_many stays non-nullable", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "users" do
            embeds_many :addresses, Address
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  addresses: Ecto.Schema.embeds_many(Address.t())
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "users", null: false do
            embeds_many :addresses, Address
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "with type override" do
    test "uses custom type instead of inferred embed type", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "users" do
            embeds_many :addresses, Address
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  addresses: list(Address.t())
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "users" do
            embeds_many :addresses, Address, typed: [type: list(Address.t())]
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "field-level override of schema options" do
    test "field enforce: false on embeds_many with schema enforce: true", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "users" do
            embeds_many :addresses, Address
            embeds_many :phones, Address
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  addresses: Ecto.Schema.embeds_many(Address.t()),
                  phones: Ecto.Schema.embeds_many(Address.t())
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "users", enforce: true do
            embeds_many :addresses, Address, typed: [enforce: false]
            embeds_many :phones, Address
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "with enforce: true" do
    test "type stays non-nullable, field added to enforce_keys", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "users" do
            embeds_many :addresses, Address
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  addresses: Ecto.Schema.embeds_many(Address.t())
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "users" do
            embeds_many :addresses, Address, typed: [enforce: true]
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "with Ecto options (on_replace: :delete)" do
    test "Ecto options do not affect the type", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "users" do
            embeds_many :addresses, Address, on_replace: :delete
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  addresses: Ecto.Schema.embeds_many(Address.t())
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "users" do
            embeds_many :addresses, Address, on_replace: :delete
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end
end
