defmodule EctoTypedSchema.Types.BelongsToTest do
  use TypeTestCase, async: true

  @compile {:no_warn_undefined, __MODULE__.Schema}

  defmodule User do
    use Ecto.Schema

    @type t() :: %__MODULE__{}

    schema "users" do
      field :name, :string
    end
  end

  describe "basic belongs_to" do
    test "generates association and foreign key types", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "posts" do
            belongs_to :author, User
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  author: Ecto.Schema.belongs_to(User.t()) | nil,
                  author_id: integer() | nil
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "posts" do
            belongs_to :author, User
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "with custom foreign_key" do
    test "uses custom foreign key name", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "posts" do
            belongs_to :creator, User, foreign_key: :creator_user_id
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  creator: Ecto.Schema.belongs_to(User.t()) | nil,
                  creator_user_id: integer() | nil
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "posts" do
            belongs_to :creator, User, foreign_key: :creator_user_id
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "with null: false" do
    test "makes both association and FK non-nullable", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "posts" do
            belongs_to :author, User
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  author: Ecto.Schema.belongs_to(User.t()),
                  author_id: integer()
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "posts" do
            belongs_to :author, User, typed: [null: false]
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "with enforce: true" do
    test "makes association non-nullable", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "posts" do
            belongs_to :author, User
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  author: Ecto.Schema.belongs_to(User.t()),
                  author_id: integer()
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "posts" do
            belongs_to :author, User, typed: [enforce: true]
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "with custom FK type" do
    test "overrides foreign key type", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "posts" do
            belongs_to :author, User
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  author: Ecto.Schema.belongs_to(User.t()) | nil,
                  author_id: Ecto.UUID.t() | nil
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "posts" do
            belongs_to :author, User, typed: [foreign_key: [type: Ecto.UUID.t()]]
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "multiple belongs_to to same schema" do
    test "generates types for all associations and foreign keys", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "posts" do
            belongs_to :author, User
            belongs_to :editor, User
            belongs_to :reviewer, User, foreign_key: :reviewer_user_id
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  author: Ecto.Schema.belongs_to(User.t()) | nil,
                  author_id: integer() | nil,
                  editor: Ecto.Schema.belongs_to(User.t()) | nil,
                  editor_id: integer() | nil,
                  reviewer: Ecto.Schema.belongs_to(User.t()) | nil,
                  reviewer_user_id: integer() | nil
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "posts" do
            belongs_to :author, User
            belongs_to :editor, User
            belongs_to :reviewer, User, foreign_key: :reviewer_user_id
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "with define_field: false" do
    test "skips auto FK field, user defines it manually", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "posts" do
            field :author_id, :binary_id
            belongs_to :author, User, define_field: false
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  author_id: Ecto.UUID.t() | nil,
                  author: Ecto.Schema.belongs_to(User.t()) | nil
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "posts" do
            field :author_id, :binary_id
            belongs_to :author, User, define_field: false
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "with binary_id FK type via Ecto option" do
    test "belongs_to with type: :binary_id", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "posts" do
            belongs_to :author, User, type: :binary_id
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  author: Ecto.Schema.belongs_to(User.t()) | nil,
                  author_id: Ecto.UUID.t() | nil
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "posts" do
            belongs_to :author, User, type: :binary_id
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "with schema-level null: false" do
    test "both association and FK become non-nullable", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "posts" do
            belongs_to :author, User
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  author: Ecto.Schema.belongs_to(User.t()),
                  author_id: integer()
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "posts", null: false do
            belongs_to :author, User
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "with @foreign_key_type :binary_id" do
    test "all belongs_to FK fields default to binary_id type", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          @foreign_key_type :binary_id

          schema "posts" do
            belongs_to :author, User
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  author: Ecto.Schema.belongs_to(User.t()) | nil,
                  author_id: Ecto.UUID.t() | nil
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          @foreign_key_type :binary_id

          typed_schema "posts" do
            belongs_to :author, User
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "with @foreign_key_type and per-field type override" do
    test "global binary_id with one integer override", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          @foreign_key_type :binary_id

          schema "posts" do
            belongs_to :author, User
            belongs_to :category, User, type: :integer
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  author: Ecto.Schema.belongs_to(User.t()) | nil,
                  author_id: Ecto.UUID.t() | nil,
                  category: Ecto.Schema.belongs_to(User.t()) | nil,
                  category_id: integer() | nil
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          @foreign_key_type :binary_id

          typed_schema "posts" do
            belongs_to :author, User
            belongs_to :category, User, type: :integer
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "with define_field: false and typed FK" do
    test "manual FK typed options are not overridden", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "posts" do
            field :author_id, :binary_id
            belongs_to :author, User, define_field: false
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  author_id: Ecto.UUID.t(),
                  author: Ecto.Schema.belongs_to(User.t()) | nil
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "posts" do
            field :author_id, :binary_id, typed: [null: false]
            belongs_to :author, User, define_field: false
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "self-referential belongs_to" do
    test "belongs_to __MODULE__", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "categories" do
            belongs_to :parent, __MODULE__
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  parent: Ecto.Schema.belongs_to(t()) | nil,
                  parent_id: integer() | nil
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "categories" do
            belongs_to :parent, __MODULE__
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end
end
