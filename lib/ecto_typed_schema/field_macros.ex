defmodule EctoTypedSchema.FieldMacros do
  @moduledoc """
  Provides typed wrappers around Ecto.Schema field macros.

  These macros capture type information during schema definition that is later
  used to generate accurate `@type t()` specifications. Each macro wraps its
  corresponding `Ecto.Schema` macro while extracting the `:typed` option for
  type customization.

  ## Type Generation Overview

  The type for each field is determined by:

  1. If `:typed` option specifies a custom `:type`, that type is used directly
  2. Otherwise, the type is inferred from the Ecto type using `EctoTypedSchema.TypeMapper`

  ## Common `:typed` Options

  All field macros support these options in the `:typed` keyword list:

    * `:type` - Override the inferred type with a custom type specification
    * `:enforce` - If `true`, adds the field to `@enforce_keys`
    * `:null` - If `false`, removes `| nil` from the type (makes it non-nullable)
    * `:default` - Sets a default value for the struct field
  """

  @doc """
  Declares a type parameter for the schema's generated type.

  Parameters make the generated type parameterized, e.g., `@type t(age) :: %__MODULE__{...}`.
  They are passed through to `TypedStructor.parameter/2`.

  ## Examples

      typed_schema "users" do
        parameter :age

        field :name, :string
        field :age, :integer, typed: [type: age]
      end

  This generates `@type t(age) :: %__MODULE__{...}` where the `:age` field
  uses the type parameter instead of the inferred `integer()` type.
  """
  defmacro parameter(name, opts \\ []) when is_atom(name) do
    quote do
      @ecto_typed_schema_parameters Keyword.merge(unquote(opts), name: unquote(name))
    end
  end

  defp validate_typed_option!(field_name, typed) do
    unless Keyword.keyword?(typed) do
      raise ArgumentError,
            "field :#{field_name} option :typed must be a keyword list, got: #{inspect(typed)}"
    end
  end

  @doc """
  Defines a typed schema field that wraps `Ecto.Schema.field/3`.

  ## Type Generation

  The generated type is inferred from the Ecto type. Common mappings include:

    * `:string` -> `String.t()`
    * `:integer` -> `integer()`
    * `:float` -> `float()`
    * `:boolean` -> `boolean()`
    * `:binary` -> `binary()`
    * `:decimal` -> `Decimal.t()`
    * `:date` -> `Date.t()`
    * `:time` / `:time_usec` -> `Time.t()`
    * `:naive_datetime` / `:naive_datetime_usec` -> `NaiveDateTime.t()`
    * `:utc_datetime` / `:utc_datetime_usec` -> `DateTime.t()`
    * `:binary_id` -> `Ecto.UUID.t()`
    * `:map` -> `map()`
    * `{:array, inner}` -> `list(inner_type)`
    * `Ecto.Enum` -> Union of atom values (e.g., `:active | :inactive`)
    * Custom module -> `Module.t()`

  By default, all field types are nullable (e.g., `String.t() | nil`).

  ## Options

  All options are passed to `Ecto.Schema.field/3` except:

    * `:typed` - Keyword list for type customization:
      * `:type` - Custom type to use instead of inferred type
      * `:enforce` - If `true`, adds field to `@enforce_keys`
      * `:null` - If `false`, makes the type non-nullable

  ## Examples

      # Basic field - generates `name: String.t() | nil`
      field :name, :string

      # Non-nullable field - generates `age: integer()`
      field :age, :integer, typed: [null: false]

      # Custom type override - generates `status: :active | :pending | :closed`
      field :status, :string, typed: [type: :active | :pending | :closed]

      # Ecto.Enum automatically generates union type
      # generates `role: :admin | :user | :guest | nil`
      field :role, Ecto.Enum, values: [:admin, :user, :guest]

      # Enforced field (required in struct creation)
      field :email, :string, typed: [enforce: true]
  """
  defmacro field(name, type \\ :string, opts \\ []) do
    {typed, opts} = Keyword.pop(opts, :typed, [])
    validate_typed_option!(name, typed)

    # Pass Ecto's default to typed options unless explicitly overridden
    # Skip nil defaults (they don't affect nullability) and when typed has null: true
    typed =
      with {:ok, default} when not is_nil(default) <- Keyword.fetch(opts, :default),
           false <- Keyword.get(typed, :null) == true do
        Keyword.put_new(typed, :default, default)
      else
        _ -> typed
      end

    # Capture enum values if this is an Ecto.Enum field
    typed =
      case type do
        Ecto.Enum ->
          case Keyword.get(opts, :values) do
            values when is_list(values) ->
              Keyword.put(typed, :enum_values, values)

            _ ->
              typed
          end

        _ ->
          typed
      end

    quote location: :keep do
      @ecto_typed_schema_typed {unquote(name), unquote(Macro.escape(typed))}

      Ecto.Schema.field(unquote(name), unquote(type), unquote(opts))
    end
  end

  @doc """
  Defines a typed `Ecto.Schema.belongs_to/3` association.

  ## Type Generation

  Generates `Ecto.Schema.belongs_to(Schema.t()) | nil` for the association field.

  This macro creates two fields:
    1. The association field (e.g., `:user`) with type `Ecto.Schema.belongs_to(User.t()) | nil`
    2. The foreign key field (e.g., `:user_id`) with type inferred from the referenced schema's primary key

  The association is nullable by default since the related record may not be loaded.

  ## Options

  All options are passed to `Ecto.Schema.belongs_to/3` except:

    * `:typed` - Keyword list for type customization:
      * `:type` - Custom type for the association field
      * `:enforce` - If `true`, adds field to `@enforce_keys`
      * `:null` - If `false`, makes the type non-nullable
      * `:foreign_key` - Keyword list with type options for the foreign key field:
        * `:type` - Custom type for the foreign key (e.g., `Ecto.UUID.t()`)

  ## Examples

      # Basic belongs_to - generates:
      #   user: Ecto.Schema.belongs_to(User.t()) | nil
      #   user_id: integer() | nil
      belongs_to :user, User

      # With custom foreign key type - generates:
      #   organization: Ecto.Schema.belongs_to(Organization.t()) | nil
      #   org_id: Ecto.UUID.t() | nil
      belongs_to :organization, Organization,
        foreign_key: :org_id,
        typed: [foreign_key: [type: Ecto.UUID.t()]]

      # Non-nullable association - generates:
      #   author: Ecto.Schema.belongs_to(Author.t())
      belongs_to :author, Author, typed: [null: false]
  """
  defmacro belongs_to(name, schema, opts \\ []) do
    {typed, opts} = Keyword.pop(opts, :typed, [])
    validate_typed_option!(name, typed)
    {foreign_key_typed, typed} = Keyword.pop(typed, :foreign_key, [])

    # Propagate null/enforce from association to FK unless FK explicitly overrides
    foreign_key_typed =
      typed
      |> Keyword.take([:null, :enforce])
      |> Keyword.merge(foreign_key_typed)

    foreign_key =
      case Keyword.fetch(opts, :foreign_key) do
        :error -> :"#{name}_id"
        {:ok, value} -> value
      end

    define_field = Keyword.get(opts, :define_field, true)

    quote location: :keep do
      @ecto_typed_schema_typed {
        unquote(name),
        unquote(
          typed
          |> Keyword.put(:schema, schema)
          |> Macro.escape()
        )
      }

      if unquote(define_field) do
        @ecto_typed_schema_typed {unquote(foreign_key),
                                  unquote(
                                    foreign_key_typed
                                    |> Keyword.put(:schema, schema)
                                    |> Macro.escape()
                                  )}
      end

      Ecto.Schema.belongs_to(unquote(name), unquote(schema), unquote(opts))
    end
  end

  @doc """
  Defines a typed `Ecto.Schema.has_one/3` association.

  ## Type Generation

  Generates `Ecto.Schema.has_one(Schema.t()) | nil` for the association field.

  The association is nullable by default since:
    1. The related record may not exist
    2. The association may not be preloaded (returns `%Ecto.Association.NotLoaded{}`)

  ## Options

  All options are passed to `Ecto.Schema.has_one/3` except:

    * `:typed` - Keyword list for type customization:
      * `:type` - Custom type for the association field
      * `:enforce` - If `true`, adds field to `@enforce_keys`
      * `:null` - If `false`, makes the type non-nullable

  ## Examples

      # Basic has_one - generates:
      #   profile: Ecto.Schema.has_one(Profile.t()) | nil
      has_one :profile, Profile

      # Non-nullable association - generates:
      #   settings: Ecto.Schema.has_one(Settings.t())
      has_one :settings, Settings, typed: [null: false]

      # With custom type override - generates:
      #   avatar: Avatar.t() | nil
      has_one :avatar, Avatar, typed: [type: Avatar.t() | nil]
  """
  # Handle has_one with through option (2 arguments)
  defmacro has_one(name, opts) when is_list(opts) do
    {typed, opts} = Keyword.pop(opts, :typed, [])
    validate_typed_option!(name, typed)

    quote location: :keep do
      @ecto_typed_schema_typed {
        unquote(name),
        unquote(
          typed
          |> Keyword.put(:through, Keyword.get(opts, :through))
          |> Macro.escape()
        )
      }

      Ecto.Schema.has_one(unquote(name), unquote(opts))
    end
  end

  defmacro has_one(name, schema, opts \\ []) do
    {typed, opts} = Keyword.pop(opts, :typed, [])
    validate_typed_option!(name, typed)

    if Keyword.has_key?(opts, :through) do
      through = Keyword.get(opts, :through)

      quote location: :keep do
        @ecto_typed_schema_typed {
          unquote(name),
          unquote(
            typed
            |> Keyword.put(:through, through)
            |> Macro.escape()
          )
        }

        Ecto.Schema.has_one(unquote(name), unquote(schema), unquote(opts))
      end
    else
      quote location: :keep do
        @ecto_typed_schema_typed {
          unquote(name),
          unquote(
            typed
            |> Keyword.put(:schema, schema)
            |> Macro.escape()
          )
        }

        Ecto.Schema.has_one(unquote(name), unquote(schema), unquote(opts))
      end
    end
  end

  @doc """
  Defines a typed `Ecto.Schema.embeds_one/3` embed.

  ## Type Generation

  Generates `Schema.t() | nil` for the embed field.

  Unlike associations which use `Ecto.Schema.has_one/1` types, embeds use the
  schema's `t()` type directly since embedded data is always loaded with the
  parent record.

  The embed is nullable by default since the embedded data may not be present.

  ## Options

  All options are passed to `Ecto.Schema.embeds_one/3` except:

    * `:typed` - Keyword list for type customization:
      * `:type` - Custom type for the embed field
      * `:enforce` - If `true`, adds field to `@enforce_keys`
      * `:null` - If `false`, makes the type non-nullable

  ## Examples

      # Basic embeds_one - generates:
      #   address: Address.t() | nil
      embeds_one :address, Address

      # Non-nullable embed - generates:
      #   profile: Profile.t()
      embeds_one :profile, Profile, typed: [null: false]

      # Enforced embed (required at struct creation) - generates:
      #   settings: Settings.t()
      embeds_one :settings, Settings, typed: [enforce: true]
  """
  defmacro embeds_one(name, schema, opts \\ []) do
    {typed, opts} = Keyword.pop(opts, :typed, [])
    validate_typed_option!(name, typed)

    quote location: :keep do
      @ecto_typed_schema_typed {
        unquote(name),
        unquote(
          typed
          |> Keyword.put(:schema, schema)
          |> Macro.escape()
        )
      }

      Ecto.Schema.embeds_one(unquote(name), unquote(schema), unquote(opts))
    end
  end

  @doc """
  Defines a typed `Ecto.Schema.embeds_one/4` embed with inline schema definition.

  ## Type Generation

  Generates `ParentModule.Schema.t() | nil` for the embed field.

  This variant creates a nested module for the embedded schema. For example,
  `embeds_one :address, Address do ... end` in `MyApp.User` creates
  `MyApp.User.Address` module with the embedded schema.

  The embed is nullable by default.

  ## Options

  All options are passed to `Ecto.Schema.embeds_one/4` except:

    * `:typed` - Keyword list for type customization:
      * `:type` - Custom type for the embed field
      * `:enforce` - If `true`, adds field to `@enforce_keys`
      * `:null` - If `false`, makes the type non-nullable

  ## Examples

      # Inline embeds_one - generates:
      #   address: __MODULE__.Address.t() | nil
      embeds_one :address, Address, primary_key: false do
        field :street, :string
        field :city, :string
      end

      # Non-nullable inline embed - generates:
      #   metadata: __MODULE__.Metadata.t()
      embeds_one :metadata, Metadata, [primary_key: false, typed: [null: false]] do
        field :version, :integer
      end
  """
  defmacro embeds_one(name, schema, opts, do: block) do
    {typed, opts} = Keyword.pop(opts, :typed, [])
    validate_typed_option!(name, typed)

    quote location: :keep do
      @ecto_typed_schema_typed {
        unquote(name),
        unquote(
          typed
          |> Keyword.put(:schema, schema)
          |> Macro.escape()
        )
      }

      Ecto.Schema.embeds_one(unquote(name), unquote(schema), unquote(opts), do: unquote(block))
    end
  end

  @doc """
  Defines a typed `Ecto.Schema.embeds_many/3` embed.

  ## Type Generation

  Generates `list(Schema.t())` for the embed field (non-nullable, defaults to `[]`).

  Unlike `embeds_one`, this type is **non-nullable** because Ecto always
  initializes `embeds_many` fields to an empty list `[]`. The embedded data
  is always loaded with the parent record.

  ## Options

  All options are passed to `Ecto.Schema.embeds_many/3` except:

    * `:typed` - Keyword list for type customization:
      * `:type` - Custom type for the embed field
      * `:enforce` - If `true`, adds field to `@enforce_keys`

  Note: The `:null` option has no effect on `embeds_many` since the type
  is always non-nullable (Ecto enforces this behavior).

  ## Examples

      # Basic embeds_many - generates:
      #   addresses: list(Address.t())
      embeds_many :addresses, Address

      # With custom type - generates:
      #   items: list(Item.t())
      embeds_many :items, Item, typed: [type: list(Item.t())]

      # Enforced (required in struct creation) - generates:
      #   tags: list(Tag.t())
      embeds_many :tags, Tag, typed: [enforce: true]
  """
  defmacro embeds_many(name, schema, opts \\ []) do
    {typed, opts} = Keyword.pop(opts, :typed, [])
    validate_typed_option!(name, typed)

    quote location: :keep do
      @ecto_typed_schema_typed {
        unquote(name),
        unquote(
          typed
          |> Keyword.put(:schema, schema)
          |> Macro.escape()
        )
      }

      Ecto.Schema.embeds_many(unquote(name), unquote(schema), unquote(opts))
    end
  end

  @doc """
  Defines a typed `Ecto.Schema.embeds_many/4` embed with inline schema definition.

  ## Type Generation

  Generates `list(ParentModule.Schema.t())` for the embed field (non-nullable, defaults to `[]`).

  This variant creates a nested module for the embedded schema. For example,
  `embeds_many :items, Item do ... end` in `MyApp.Order` creates
  `MyApp.Order.Item` module with the embedded schema.

  The type is **non-nullable** because Ecto always initializes `embeds_many`
  fields to an empty list `[]`.

  ## Options

  All options are passed to `Ecto.Schema.embeds_many/4` except:

    * `:typed` - Keyword list for type customization:
      * `:type` - Custom type for the embed field
      * `:enforce` - If `true`, adds field to `@enforce_keys`

  ## Examples

      # Inline embeds_many - generates:
      #   line_items: list(__MODULE__.LineItem.t())
      embeds_many :line_items, LineItem, primary_key: false do
        field :product_name, :string
        field :quantity, :integer
        field :price, :decimal
      end

      # With options - generates:
      #   tags: list(__MODULE__.Tag.t())
      embeds_many :tags, Tag, [on_replace: :delete, typed: [enforce: true]] do
        field :name, :string
      end
  """
  defmacro embeds_many(name, schema, opts, do: block) do
    {typed, opts} = Keyword.pop(opts, :typed, [])
    validate_typed_option!(name, typed)

    quote location: :keep do
      @ecto_typed_schema_typed {
        unquote(name),
        unquote(
          typed
          |> Keyword.put(:schema, schema)
          |> Macro.escape()
        )
      }

      Ecto.Schema.embeds_many(unquote(name), unquote(schema), unquote(opts), do: unquote(block))
    end
  end

  @doc """
  Defines a typed `Ecto.Schema.has_many/3` association.

  ## Type Generation

  Generates `Ecto.Schema.has_many(Schema.t())` for the association field (non-nullable, defaults to `[]`).

  Unlike `has_one` and `belongs_to`, the `has_many` type is **non-nullable** because
  when loaded, it always returns a list (possibly empty), never `nil`. This matches
  Ecto's runtime behavior where loaded `has_many` associations are always lists.

  ## Variants

  This macro has two forms:
    * `has_many(name, schema, opts)` - Standard has_many association
    * `has_many(name, opts)` - Through association (when opts contains `:through`)

  ## Options

  All options are passed to `Ecto.Schema.has_many/3` except:

    * `:typed` - Keyword list for type customization:
      * `:type` - Custom type for the association field
      * `:enforce` - If `true`, adds field to `@enforce_keys`

  Note: The `:null` option has no effect on `has_many` since the type
  is always non-nullable (Ecto enforces this behavior).

  ## Examples

      # Basic has_many - generates:
      #   posts: Ecto.Schema.has_many(Post.t())
      has_many :posts, Post, foreign_key: :user_id

      # With custom type - generates:
      #   comments: list(Comment.t())
      has_many :comments, Comment, typed: [type: list(Comment.t())]

      # Through association - generates:
      #   tags: Ecto.Schema.has_many(Tag.t())
      has_many :post_tags, through: [:posts, :tags]

      # Enforced (required in struct creation) - generates:
      #   items: Ecto.Schema.has_many(Item.t())
      has_many :items, Item, typed: [enforce: true]
  """
  # Handle has_many with through option (2 arguments)
  defmacro has_many(name, opts) when is_list(opts) do
    {typed, opts} = Keyword.pop(opts, :typed, [])
    validate_typed_option!(name, typed)

    quote location: :keep do
      # For through associations, we store the through option
      @ecto_typed_schema_typed {
        unquote(name),
        unquote(
          typed
          |> Keyword.put(:through, Keyword.get(opts, :through))
          |> Macro.escape()
        )
      }

      Ecto.Schema.has_many(unquote(name), unquote(opts))
    end
  end

  defmacro has_many(name, schema, opts \\ []) do
    {typed, opts} = Keyword.pop(opts, :typed, [])
    validate_typed_option!(name, typed)

    if Keyword.has_key?(opts, :through) do
      through = Keyword.get(opts, :through)

      quote location: :keep do
        @ecto_typed_schema_typed {
          unquote(name),
          unquote(
            typed
            |> Keyword.put(:through, through)
            |> Macro.escape()
          )
        }

        Ecto.Schema.has_many(unquote(name), unquote(schema), unquote(opts))
      end
    else
      quote location: :keep do
        @ecto_typed_schema_typed {
          unquote(name),
          unquote(
            typed
            |> Keyword.put(:schema, schema)
            |> Macro.escape()
          )
        }

        Ecto.Schema.has_many(unquote(name), unquote(schema), unquote(opts))
      end
    end
  end

  @doc """
  Defines a typed `Ecto.Schema.many_to_many/3` association.

  ## Type Generation

  Generates `Ecto.Schema.many_to_many(Schema.t())` for the association field (non-nullable, defaults to `[]`).

  Like `has_many`, the `many_to_many` type is **non-nullable** because when loaded,
  it always returns a list (possibly empty), never `nil`. This matches Ecto's
  runtime behavior where loaded `many_to_many` associations are always lists.

  ## Options

  All options are passed to `Ecto.Schema.many_to_many/3` except:

    * `:typed` - Keyword list for type customization:
      * `:type` - Custom type for the association field
      * `:enforce` - If `true`, adds field to `@enforce_keys`

  Note: The `:null` option has no effect on `many_to_many` since the type
  is always non-nullable (Ecto enforces this behavior).

  ## Examples

      # Basic many_to_many - generates:
      #   tags: Ecto.Schema.many_to_many(Tag.t())
      many_to_many :tags, Tag, join_through: "posts_tags"

      # With custom type - generates:
      #   categories: list(Category.t())
      many_to_many :categories, Category,
        join_through: "posts_categories",
        typed: [type: list(Category.t())]

      # With join schema - generates:
      #   roles: Ecto.Schema.many_to_many(Role.t())
      many_to_many :roles, Role, join_through: UserRole

      # Enforced (required in struct creation) - generates:
      #   permissions: Ecto.Schema.many_to_many(Permission.t())
      many_to_many :permissions, Permission,
        join_through: "user_permissions",
        typed: [enforce: true]
  """
  defmacro many_to_many(name, schema, opts \\ []) do
    {typed, opts} = Keyword.pop(opts, :typed, [])
    validate_typed_option!(name, typed)

    quote location: :keep do
      @ecto_typed_schema_typed {
        unquote(name),
        unquote(
          typed
          |> Keyword.put(:schema, schema)
          |> Macro.escape()
        )
      }

      Ecto.Schema.many_to_many(unquote(name), unquote(schema), unquote(opts))
    end
  end

  @doc """
  Defines typed timestamp fields that wrap `Ecto.Schema.timestamps/1`.

  ## Type Generation

  By default, generates `NaiveDateTime.t() | nil` for both `inserted_at` and `updated_at` fields.

  The timestamp type depends on the `:type` option passed to Ecto:
    * `:naive_datetime` (default) -> `NaiveDateTime.t()`
    * `:naive_datetime_usec` -> `NaiveDateTime.t()`
    * `:utc_datetime` -> `DateTime.t()`
    * `:utc_datetime_usec` -> `DateTime.t()`

  Timestamps are nullable by default since they are typically set by the database
  or Ecto callbacks, not at struct creation time.

  ## Options

  All options are passed to `Ecto.Schema.timestamps/1` except:

    * `:typed` - Keyword list for type customization (applies to both timestamp fields):
      * `:type` - Custom type for both timestamp fields
      * `:enforce` - If `true`, adds both fields to `@enforce_keys`
      * `:null` - If `false`, makes both types non-nullable

  ## Common Ecto Options

    * `:inserted_at` - Name of the inserted_at field (default: `:inserted_at`), set to `false` to disable
    * `:updated_at` - Name of the updated_at field (default: `:updated_at`), set to `false` to disable
    * `:type` - The Ecto timestamp type (default: `:naive_datetime`)

  ## Examples

      # Default timestamps - generates:
      #   inserted_at: NaiveDateTime.t() | nil
      #   updated_at: NaiveDateTime.t() | nil
      timestamps()

      # UTC datetime timestamps - generates:
      #   inserted_at: DateTime.t() | nil
      #   updated_at: DateTime.t() | nil
      timestamps(type: :utc_datetime)

      # Non-nullable timestamps - generates:
      #   inserted_at: NaiveDateTime.t()
      #   updated_at: NaiveDateTime.t()
      timestamps(typed: [null: false])

      # Custom field names - generates:
      #   created_at: NaiveDateTime.t() | nil
      #   modified_at: NaiveDateTime.t() | nil
      timestamps(inserted_at: :created_at, updated_at: :modified_at)

      # Only inserted_at - generates:
      #   inserted_at: NaiveDateTime.t() | nil
      timestamps(updated_at: false)
  """
  defmacro timestamps(opts \\ []) do
    {typed, opts} = Keyword.pop(opts, :typed, [])
    validate_typed_option!(:timestamps, typed)

    quote location: :keep do
      # Merge @timestamps_opts (if defined) with explicit opts
      # Explicit opts take precedence over @timestamps_opts
      timestamps_defaults =
        if Module.has_attribute?(__MODULE__, :timestamps_opts) do
          @timestamps_opts
        else
          []
        end

      merged_opts = Keyword.merge(timestamps_defaults, unquote(opts))

      inserted_at = Keyword.get(merged_opts, :inserted_at, :inserted_at)
      updated_at = Keyword.get(merged_opts, :updated_at, :updated_at)

      if inserted_at do
        @ecto_typed_schema_typed {inserted_at, unquote(Macro.escape(typed))}
      end

      if updated_at do
        @ecto_typed_schema_typed {updated_at, unquote(Macro.escape(typed))}
      end

      Ecto.Schema.timestamps(unquote(opts))
    end
  end
end
