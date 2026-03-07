defmodule EctoTypedSchema.Types.ManyToManyTest do
  use TypeTestCase, async: true

  @compile {:no_warn_undefined, __MODULE__.Schema}

  defmodule Tag do
    use Ecto.Schema

    @type t() :: %__MODULE__{}

    schema "tags" do
      field :name, :string
    end
  end

  defmodule Category do
    use Ecto.Schema

    @type t() :: %__MODULE__{}

    schema "categories" do
      field :name, :string
    end
  end

  defmodule PostTag do
    use Ecto.Schema

    @type t() :: %__MODULE__{}

    schema "posts_tags" do
      field :post_id, :integer
      field :tag_id, :integer
    end
  end

  describe "with join_through string" do
    test "generates many_to_many association type", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "posts" do
            many_to_many :tags, Tag, join_through: "posts_tags"
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  tags: Ecto.Schema.many_to_many(Tag.t())
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "posts" do
            many_to_many :tags, Tag, join_through: "posts_tags"
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "with join_through schema module" do
    test "generates many_to_many association type", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "posts" do
            many_to_many :tags, Tag, join_through: PostTag
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  tags: Ecto.Schema.many_to_many(Tag.t())
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "posts" do
            many_to_many :tags, Tag, join_through: PostTag
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

          schema "posts" do
            many_to_many :tags, Tag, join_through: "posts_tags"
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  tags: list(Tag.t())
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "posts" do
            many_to_many :tags, Tag,
              join_through: "posts_tags",
              typed: [type: list(Tag.t())]
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "multiple many_to_many associations" do
    test "generates types for all associations", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "posts" do
            many_to_many :tags, Tag, join_through: "posts_tags"
            many_to_many :categories, Category, join_through: "posts_categories"
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  tags: Ecto.Schema.many_to_many(Tag.t()),
                  categories: Ecto.Schema.many_to_many(Category.t())
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "posts" do
            many_to_many :tags, Tag, join_through: "posts_tags"
            many_to_many :categories, Category, join_through: "posts_categories"
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "with schema-level null: false" do
    test "many_to_many stays non-nullable", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "posts" do
            many_to_many :tags, Tag, join_through: "posts_tags"
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  tags: Ecto.Schema.many_to_many(Tag.t())
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "posts", null: false do
            many_to_many :tags, Tag, join_through: "posts_tags"
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end
end
