# EctoTypedSchema

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Ecto schemas don't generate `@type t()` specs. You either maintain them by hand
(tedious, drifts out of sync) or skip them entirely (no Dialyzer/IDE support).

EctoTypedSchema infers types automatically from your Ecto field definitions -- just
replace `use Ecto.Schema` with `use EctoTypedSchema` and `schema` with `typed_schema`.

**Before** -- manual `@type` that drifts out of sync:

```elixir
defmodule MyApp.User do
  use Ecto.Schema

  schema "users" do
    field :name, :string
    field :age, :integer
    has_many :posts, MyApp.Post
  end

  # Must maintain by hand, easy to forget
  @type t() :: %__MODULE__{
    __meta__: Ecto.Schema.Metadata.t(),
    id: integer() | nil,
    name: String.t() | nil,
    age: integer() | nil,
    posts: list(MyApp.Post.t())
  }
end
```

**After** -- types inferred automatically:

```elixir
defmodule MyApp.User do
  use EctoTypedSchema

  typed_schema "users" do
    field :name, :string
    field :age, :integer, typed: [null: false]
    has_many :posts, MyApp.Post
  end
end
```

## Feature Highlights

- **Zero-annotation inference** -- Ecto types mapped to typespecs automatically (`:string` -> `String.t()`, `:integer` -> `integer()`, etc.)
- **Association-aware** -- `belongs_to`, `has_many`, `has_one`, `many_to_many`, and embeds all generate correct types
- **Ecto runtime semantics** -- primary keys non-nullable, `has_many`/`embeds_many` default to `[]`, everything else nullable
- **Fine-grained control** -- override per-field with `typed: [null: false]`, `typed: [type: ...]`, or `typed: [enforce: true]`
- **Schema-level defaults** -- set `null:`, `enforce:`, `type_kind:`, `type_name:` for all fields at once
- **Through associations** -- resolved at compile time with fallback warning
- **Plugin system** -- forward [TypedStructor plugins](https://hexdocs.pm/typed_structor/TypedStructor.Plugin.html) into the generated type block
- **Embedded schemas** -- `typed_embedded_schema` works the same way, without `__meta__`

## Installation

```elixir
def deps do
  [
    {:ecto_typed_schema, github: "fahchen/ecto_typed_schema"},
    {:ecto, "~> 3.10"}
  ]
end
```

<!-- MODULEDOC -->

## Getting Started

Use `typed_schema` as a drop-in replacement for `Ecto.Schema.schema`:

```elixir
defmodule MyApp.Blog.Post do
  use EctoTypedSchema

  typed_schema "posts" do
    field :title, :string, typed: [null: false]
    field :status, Ecto.Enum, values: [:draft, :published]

    belongs_to :author, MyApp.Accounts.User
    has_many :comments, MyApp.Blog.Comment
    timestamps()
  end
end
```

This generates:

```elixir
@type t() :: %MyApp.Blog.Post{
  __meta__: Ecto.Schema.Metadata.t(MyApp.Blog.Post),
  id: integer(),
  title: String.t(),
  status: :draft | :published | nil,
  author_id: integer() | nil,
  author: Ecto.Schema.belongs_to(MyApp.Accounts.User.t()) | nil,
  comments: Ecto.Schema.has_many(MyApp.Blog.Comment.t()),
  inserted_at: NaiveDateTime.t() | nil,
  updated_at: NaiveDateTime.t() | nil
}
```

You can verify the generated type in IEx:

```
iex> t MyApp.Blog.Post
@type t() :: %MyApp.Blog.Post{...}
```

## Options

### Type Parameters

Create parameterized types with `parameter/2`:

```elixir
typed_embedded_schema type_kind: :opaque, type_name: :result, null: false do
  parameter :ok
  parameter :error

  field :ok, :string, typed: [type: ok]
  field :error, :string, typed: [type: error]
end
# Generates: @opaque result(ok, error) :: %__MODULE__{...}
```

### Plugins

Register [TypedStructor plugins](https://hexdocs.pm/typed_structor/TypedStructor.Plugin.html)
to extend the generated type definition:

```elixir
typed_schema "users" do
  plugin MyPlugin, some_option: true
  field :name, :string
end
```

Plugins are forwarded into the generated `typed_structor` block and receive all
three callbacks (`init`, `before_definition`, `after_definition`).

### Embedded Schemas

```elixir
typed_embedded_schema do
  field :display_name, :string
  field :bio, :string
end
```

Embedded schema types omit `__meta__`.

## Edge Cases

### Through associations

`through:` associations are included in the generated type. If the chain can't be resolved at compile time, the type falls back to `term()` / `list(term())` with a warning. Provide an explicit type to suppress:

```elixir
has_many :post_tags, through: [:posts, :tags], typed: [type: list(Tag.t())]
```

### `belongs_to` with `define_field: false`

No typed metadata is generated for the FK field. Define it manually with `field/3` if you need custom type settings.

### `default: nil`

Does not make a field non-nullable; the type stays `... | nil`.

<!-- MODULEDOC -->

## Related

- [TypedStructor](https://github.com/elixir-typed-structor/typed_structor) -- the type generation engine behind EctoTypedSchema
- [Ecto](https://github.com/elixir-ecto/ecto) -- the database wrapper and query generator for Elixir
