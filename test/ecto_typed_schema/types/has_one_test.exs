defmodule EctoTypedSchema.Types.HasOneTest do
  use TypeTestCase, async: true

  @compile {:no_warn_undefined, __MODULE__.Schema}

  defmodule Profile do
    use Ecto.Schema

    @type t() :: %__MODULE__{}

    schema "profiles" do
      field :bio, :string
      field :user_id, :integer
      field :primary_user_id, :integer
    end
  end

  describe "basic has_one" do
    test "generates association type with nil", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "users" do
            has_one :profile, Profile, foreign_key: :user_id
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  profile: Ecto.Schema.has_one(Profile.t()) | nil
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "users" do
            has_one :profile, Profile, foreign_key: :user_id
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "with null: false" do
    test "makes association non-nullable", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "users" do
            has_one :profile, Profile, foreign_key: :user_id
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  profile: Ecto.Schema.has_one(Profile.t())
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "users" do
            has_one :profile, Profile, foreign_key: :user_id, typed: [null: false]
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "with type override" do
    test "uses custom type instead of inferred association type", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "users" do
            has_one :profile, Profile, foreign_key: :user_id
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  profile: Profile.t() | nil
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "users" do
            has_one :profile, Profile, foreign_key: :user_id, typed: [type: Profile.t()]
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "with custom foreign_key" do
    test "foreign_key does not affect parent type", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "users" do
            has_one :main_profile, Profile, foreign_key: :primary_user_id
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  main_profile: Ecto.Schema.has_one(Profile.t()) | nil
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "users" do
            has_one :main_profile, Profile, foreign_key: :primary_user_id
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "with schema-level null: false" do
    test "propagates to has_one", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "users" do
            has_one :profile, Profile, foreign_key: :user_id
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  profile: Ecto.Schema.has_one(Profile.t())
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "users", null: false do
            has_one :profile, Profile, foreign_key: :user_id
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "through association" do
    defmodule Account do
      use Ecto.Schema

      @type t() :: %__MODULE__{}

      schema "accounts" do
        field :user_id, :integer
        has_one :profile, Profile, foreign_key: :user_id
      end
    end

    test "resolves the target schema through the association chain", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "users" do
            has_one :account, Account, foreign_key: :user_id
            has_one :account_profile, through: [:account, :profile]
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  account: Ecto.Schema.has_one(Account.t()) | nil,
                  account_profile: Ecto.Schema.has_one(Profile.t()) | nil
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "users" do
            has_one :account, Account, foreign_key: :user_id
            has_one :account_profile, through: [:account, :profile]
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "multiple has_one associations" do
    defmodule Settings do
      use Ecto.Schema

      @type t() :: %__MODULE__{}

      schema "settings" do
        field :user_id, :integer
      end
    end

    test "two has_one to different schemas", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "users" do
            has_one :profile, Profile, foreign_key: :user_id
            has_one :settings, Settings, foreign_key: :user_id
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  profile: Ecto.Schema.has_one(Profile.t()) | nil,
                  settings: Ecto.Schema.has_one(Settings.t()) | nil
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "users" do
            has_one :profile, Profile, foreign_key: :user_id
            has_one :settings, Settings, foreign_key: :user_id
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "through association fallback warning" do
    test "emits warning when through chain cannot be resolved", ctx do
      warnings =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          with_tmpmodule Schema, ctx do
            use EctoTypedSchema

            typed_schema "users" do
              has_one :profile, Profile, foreign_key: :user_id
              # :nonexistent doesn't exist on Profile, so resolution fails
              has_one :profile_detail, through: [:profile, :nonexistent]
            end
          after
            fetch_types!(Schema)
          end
        end)

      assert warnings =~ "profile_detail"
      assert warnings =~ ":profile, :nonexistent"
      assert warnings =~ "typed: [type: ...]"
    end
  end
end
