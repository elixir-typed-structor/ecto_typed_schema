defmodule EctoTypedSchema.Types.EmbedsOneTest do
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

  describe "basic embeds_one (nullable by default)" do
    test "generates embed type with nil", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "users" do
            embeds_one :address, Address
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  address: Ecto.Schema.embeds_one(Address.t()) | nil
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "users" do
            embeds_one :address, Address
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "inline schema definition" do
    test "generates inline embed type with nil", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "users" do
            embeds_one :address, Address, primary_key: false do
              field :street, :string
              field :city, :string
            end
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  address: Ecto.Schema.embeds_one(__MODULE__.Address.t()) | nil
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "users" do
            embeds_one :address, Address, primary_key: false do
              field :street, :string
              field :city, :string
            end
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end

    test "inline child module gets @type t()", ctx do
      with_tmpmodule Schema, ctx do
        use EctoTypedSchema

        typed_schema "users" do
          embeds_one :address, Address, primary_key: false do
            field :street, :string
            field :city, :string
          end
        end
      after
        child_types = fetch_types!(Schema.Address)
        assert [{:type, {:t, _, _}}] = child_types

        type_string =
          child_types
          |> Enum.map(fn {kind, type} ->
            "@#{kind} #{Macro.to_string(Code.Typespec.type_to_quoted(type))}"
          end)
          |> Enum.join("\n")

        assert type_string =~ "street: String.t() | nil"
        assert type_string =~ "city: String.t() | nil"
      end
    end

    test "inline embeds_one with typed: [null: false] makes parent type non-nullable", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "users" do
            embeds_one :address, Address, primary_key: false do
              field :city, :string
            end
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  address: Ecto.Schema.embeds_one(__MODULE__.Address.t())
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "users" do
            embeds_one :address, Address, primary_key: false, typed: [null: false] do
              field :city, :string
            end
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end

    test "inline embeds_one with primary_key: false — child has no :id in type", ctx do
      with_tmpmodule Schema, ctx do
        use EctoTypedSchema

        typed_schema "users" do
          embeds_one :address, Address, primary_key: false do
            field :city, :string
          end
        end
      after
        child_types = fetch_types!(Schema.Address)

        type_string =
          child_types
          |> Enum.map(fn {kind, type} ->
            "@#{kind} #{Macro.to_string(Code.Typespec.type_to_quoted(type))}"
          end)
          |> Enum.join("\n")

        refute type_string =~ "id:"
        assert type_string =~ "city: String.t() | nil"
      end
    end

    test "multi-level nested inline embeds compile and generate types", ctx do
      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "orders" do
            field :total, :decimal

            embeds_one :shipping, Shipping, primary_key: false do
              field :carrier, :string

              embeds_one :address, Address, primary_key: false do
                field :city, :string
                field :zip, :string
              end
            end
          end
        after
          parent_types = fetch_types!(Schema)
          shipping_types = fetch_types!(Schema.Shipping)
          address_types = fetch_types!(Schema.Shipping.Address)

          {parent_types, shipping_types, address_types}
        end

      {parent_types, shipping_types, address_types} = generated_types

      to_string = fn types ->
        Enum.map_join(types, "\n", fn {kind, type} ->
          "@#{kind} #{Macro.to_string(Code.Typespec.type_to_quoted(type))}"
        end)
      end

      parent_str = to_string.(parent_types)
      assert parent_str =~ "shipping: Ecto.Schema.embeds_one("
      assert parent_str =~ "total: Decimal.t() | nil"

      shipping_str = to_string.(shipping_types)
      assert shipping_str =~ "carrier: String.t() | nil"
      assert shipping_str =~ "Ecto.Schema.embeds_one("
      assert shipping_str =~ "Shipping.Address.t()"

      address_str = to_string.(address_types)
      assert address_str =~ "city: String.t() | nil"
      assert address_str =~ "zip: String.t() | nil"
    end
  end

  describe "with null: false" do
    test "makes embed non-nullable", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "users" do
            embeds_one :address, Address
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  address: Ecto.Schema.embeds_one(Address.t())
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "users" do
            embeds_one :address, Address, typed: [null: false]
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "with schema-level null: false" do
    test "embeds_one becomes non-nullable", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "users" do
            embeds_one :address, Address
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  address: Ecto.Schema.embeds_one(Address.t())
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "users", null: false do
            embeds_one :address, Address
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
            embeds_one :address, Address
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  address: Address.t()
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "users" do
            embeds_one :address, Address, typed: [type: Address.t(), null: false]
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
            embeds_one :address, Address, on_replace: :delete
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  address: Ecto.Schema.embeds_one(Address.t()) | nil
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "users" do
            embeds_one :address, Address, on_replace: :delete
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end
end
