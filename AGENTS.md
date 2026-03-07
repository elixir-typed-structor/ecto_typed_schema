# AGENTS.md

This file is the execution guide for coding agents working in this repository.
Focus on correctness of generated types first, then maintainability.

## Command Quickstart

```bash
# Run all tests
mix test

# Run a single test file
mix test test/ecto_typed_schema/types/field_test.exs

# Run a specific test by line number
mix test test/ecto_typed_schema/types/field_test.exs:42

# Compile and treat warnings as errors
mix compile --warnings-as-errors

# Format
mix format
```

## Agent Workflow

1. Discover impact first with `rg`/`fd` before editing.
2. Keep changes minimal and local to the requested scope.
3. For behavior changes, update or add tests in `test/ecto_typed_schema/types/`.
4. Validate with targeted tests first, then run `mix test`.
5. If editing macro/type-generation logic, run `mix compile --warnings-as-errors`.

## Architecture Snapshot

EctoTypedSchema generates `@type` specs from Ecto schema definitions by combining
`Ecto.Schema` metadata with `TypedStructor` (type-only mode, `define_struct: false`).

### Compile-time Pipeline

1. `__using__/1` sets up `Ecto.Schema`, `TypedStructor`, and module attributes.
2. `typed_schema/3` or `typed_embedded_schema/2` wraps Ecto schema macros and imports `FieldMacros`.
3. `FieldMacros` wrappers call real `Ecto.Schema` macros and capture typed metadata.
4. `@on_definition` captures Ecto's generated `__changeset__/0` body.
5. `__before_compile__/1` extracts field/type info, resolves overrides, and emits a `typed_structor` block.

### Core Modules

- `lib/ecto_typed_schema.ex`: compile-time orchestration, through resolution, warning emission
- `lib/ecto_typed_schema/field_macros.ex`: macro wrappers (`field`, associations, embeds, `parameter`, `plugin`)
- `lib/ecto_typed_schema/type_mapper.ex`: Ecto type -> Elixir typespec mapping
- `lib/ecto_typed_schema/changeset_extractor.ex`: `__changeset__/0` AST extraction

## Supported Features You Must Preserve

- Schema-level defaults: `null`, plus `type_kind` and `type_name`
- Type parameters via `parameter/2` with declaration-order preservation
- TypedStructor plugin forwarding via `plugin/2` with declaration-order preservation
- Through-association type generation for fields absent from `__changeset__/0`
- Compile-time warning on unresolved through chains, including hint:
  `typed: [type: ...]`
- Fallback behavior when through resolution fails:
  - `has_one ... through` -> `term()`
  - `has_many ... through` -> `list(term())`
- `:many` normalization remains list-shaped (`null: false`, `default: []`)
- `field ... default: nil` remains nullable in generated types
- `belongs_to(..., define_field: false)` must not synthesize FK typed metadata

## Test Strategy

- Tests live in `test/ecto_typed_schema/types/` and compare generated vs expected types.
- Use `test/support/type_test_case.ex` helpers (`with_tmpmodule`, `fetch_types!`).
- `with_tmpmodule` compiles modules in isolation; cross-module compile-order behavior
  may need fixture modules under `lib/ecto_typed_schema/examples/`.

Recommended sequence:

1. Run the most relevant file-level test(s).
2. Run `mix test` for full regression coverage.
3. Run `mix compile --warnings-as-errors` after macro changes.

## Dependencies

- `typed_structor` `~> 0.6` (Hex package)
- `ecto` `~> 3.10`
