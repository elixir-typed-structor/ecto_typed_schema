# Used by "mix format"
locals_without_parens = [
  typed_schema: 1,
  typed_schema: 2,
  typed_embedded_schema: 1,
  typed_embedded_schema: 2,
  field: 1,
  field: 2,
  field: 3,
  belongs_to: 2,
  belongs_to: 3,
  has_one: 2,
  has_one: 3,
  has_many: 2,
  has_many: 3,
  many_to_many: 2,
  many_to_many: 3,
  embeds_one: 2,
  embeds_one: 3,
  embeds_one: 4,
  embeds_many: 2,
  embeds_many: 3,
  embeds_many: 4,
  timestamps: 0,
  timestamps: 1,
  parameter: 1,
  parameter: 2,
  plugin: 1,
  plugin: 2
]

[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  locals_without_parens: locals_without_parens,
  export: [locals_without_parens: locals_without_parens],
  import_deps: [:ecto, :typed_structor]
]
