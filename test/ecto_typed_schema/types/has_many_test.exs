defmodule EctoTypedSchema.Types.HasManyTest do
  use TypeTestCase, async: true

  @compile {:no_warn_undefined, __MODULE__.Schema}

  defmodule Tag do
    use Ecto.Schema

    @type t() :: %__MODULE__{}

    schema "tags" do
      field :name, :string
      field :post_id, :integer
    end
  end

  defmodule Post do
    use Ecto.Schema

    @type t() :: %__MODULE__{}

    schema "posts" do
      field :user_id, :integer
      field :title, :string
      has_many :tags, EctoTypedSchema.Types.HasManyTest.Tag, foreign_key: :post_id
    end
  end

  defmodule PostWithMultipleFK do
    use Ecto.Schema

    @type t() :: %__MODULE__{}

    schema "posts" do
      field :author_id, :integer
      field :editor_id, :integer
      field :title, :string
    end
  end

  describe "basic has_many" do
    test "generates non-nullable association type", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "users" do
            has_many :posts, Post, foreign_key: :user_id
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  posts: Ecto.Schema.has_many(Post.t())
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "users" do
            has_many :posts, Post, foreign_key: :user_id
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
            has_many :posts, Post, foreign_key: :user_id
          end

          @type post_list() :: [Post.t()]

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  posts: post_list()
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          @type post_list() :: [Post.t()]

          typed_schema "users" do
            has_many :posts, Post, foreign_key: :user_id, typed: [type: post_list()]
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "through association" do
    test "resolves the target schema through the association chain", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "users" do
            has_many :posts, Post, foreign_key: :user_id
            has_many :post_tags, through: [:posts, :tags]
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  posts: Ecto.Schema.has_many(Post.t()),
                  post_tags: Ecto.Schema.has_many(Tag.t())
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "users" do
            has_many :posts, Post, foreign_key: :user_id
            has_many :post_tags, through: [:posts, :tags]
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "self-referential" do
    test "generates correct types for self-referencing association", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "posts" do
            belongs_to :parent, __MODULE__
            has_many :replies, __MODULE__, foreign_key: :parent_id
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  parent: Ecto.Schema.belongs_to(t()) | nil,
                  parent_id: integer() | nil,
                  replies: Ecto.Schema.has_many(t())
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "posts" do
            belongs_to :parent, __MODULE__
            has_many :replies, __MODULE__, foreign_key: :parent_id
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "multiple has_many to different foreign keys" do
    test "generates types for all associations", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "users" do
            has_many :authored_posts, PostWithMultipleFK, foreign_key: :author_id
            has_many :edited_posts, PostWithMultipleFK, foreign_key: :editor_id
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  authored_posts: Ecto.Schema.has_many(PostWithMultipleFK.t()),
                  edited_posts: Ecto.Schema.has_many(PostWithMultipleFK.t())
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "users" do
            has_many :authored_posts, PostWithMultipleFK, foreign_key: :author_id
            has_many :edited_posts, PostWithMultipleFK, foreign_key: :editor_id
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "with schema-level null: false" do
    test "has_many stays non-nullable (already non-nullable by default)", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "users" do
            has_many :posts, Post, foreign_key: :user_id
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  posts: Ecto.Schema.has_many(Post.t())
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "users", null: false do
            has_many :posts, Post, foreign_key: :user_id
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
            has_many :posts, Post, foreign_key: :user_id
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  posts: Ecto.Schema.has_many(Post.t())
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "users" do
            has_many :posts, Post, foreign_key: :user_id, typed: [enforce: true]
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "with custom source tuple" do
    test "has_many with {source, schema} tuple", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "users" do
            has_many :posts, {"custom_posts", Post}, foreign_key: :user_id
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  posts: Ecto.Schema.has_many(Post.t())
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "users" do
            has_many :posts, {"custom_posts", Post}, foreign_key: :user_id
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "through association with 3-step chain" do
    defmodule Author do
      use Ecto.Schema

      @type t() :: %__MODULE__{}

      schema "authors" do
        field :name, :string
        has_many :posts, EctoTypedSchema.Types.HasManyTest.Post, foreign_key: :user_id
      end
    end

    defmodule Team do
      use Ecto.Schema

      @type t() :: %__MODULE__{}

      schema "teams" do
        field :name, :string
        has_many :authors, Author, foreign_key: :id
      end
    end

    test "resolves through 3-step chain", ctx do
      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "organizations" do
            has_many :teams, Team, foreign_key: :id
            has_many :team_authors, through: [:teams, :authors]
            has_many :team_author_posts, through: [:teams, :authors, :posts]
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  teams: Ecto.Schema.has_many(Team.t()),
                  team_authors: Ecto.Schema.has_many(Author.t()),
                  team_author_posts: Ecto.Schema.has_many(Post.t())
                }
        after
          fetch_types!(Schema)
        end

      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "organizations" do
            has_many :teams, Team, foreign_key: :id
            has_many :team_authors, through: [:teams, :authors]
            has_many :team_author_posts, through: [:teams, :authors, :posts]
          end
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end
end
