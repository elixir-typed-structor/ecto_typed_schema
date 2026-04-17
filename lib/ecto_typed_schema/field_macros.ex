defmodule EctoTypedSchema.FieldMacros do
  @moduledoc false

  @spec parameter(atom(), keyword()) :: Macro.t()
  defmacro parameter(name, opts \\ []) when is_atom(name) do
    quote do
      @ecto_typed_schema_parameters Keyword.merge(unquote(opts), name: unquote(name))
    end
  end

  @spec plugin(module(), keyword()) :: Macro.t()
  defmacro plugin(plugin, opts \\ []) do
    quote do
      @ecto_typed_schema_plugins {unquote(plugin), unquote(opts)}
    end
  end

  @spec field(atom(), atom() | module(), keyword()) :: Macro.t()
  defmacro field(name, type \\ :string, opts \\ []) do
    {typed, opts} = Keyword.pop(opts, :typed, [])
    typed = sanitize_typed_opts(typed)

    # Propagate non-nil Ecto defaults to typed opts so TypedStructor sees them,
    # unless the field is explicitly nullable (null: true).
    typed =
      with {:ok, default} when not is_nil(default) <- Keyword.fetch(opts, :default),
           false <- Keyword.get(typed, :null) == true do
        Keyword.put_new(typed, :default, default)
      else
        _ -> typed
      end

    # Capture enum values so TypeMapper can generate a union type.
    typed =
      case type do
        Ecto.Enum ->
          case Keyword.get(opts, :values) do
            values when is_list(values) -> Keyword.put(typed, :enum_values, values)
            _ -> typed
          end

        _ ->
          typed
      end

    quote location: :keep do
      @ecto_typed_schema_typed {unquote(name), unquote(Macro.escape(typed))}

      Ecto.Schema.field(unquote(name), unquote(type), unquote(opts))
    end
  end

  @supported_typed_keys [:type, :null, :default, :enum_values, :through, :foreign_key]

  @spec sanitize_typed_opts(keyword()) :: keyword()
  defp sanitize_typed_opts(typed), do: Keyword.take(typed, @supported_typed_keys)

  @spec belongs_to(atom(), module(), keyword()) :: Macro.t()
  defmacro belongs_to(name, schema, opts \\ []) do
    {typed, opts} = Keyword.pop(opts, :typed, [])
    typed = sanitize_typed_opts(typed)
    {foreign_key_typed, typed} = Keyword.pop(typed, :foreign_key, [])

    foreign_key =
      case Keyword.fetch(opts, :foreign_key) do
        :error -> :"#{name}_id"
        {:ok, value} -> value
      end

    foreign_key_typed = sanitize_typed_opts(foreign_key_typed)

    # Propagate null from association to FK unless FK explicitly overrides
    foreign_key_typed =
      typed
      |> Keyword.take([:null])
      |> Keyword.merge(foreign_key_typed)

    define_field = Keyword.get(opts, :define_field, true)

    quote location: :keep do
      @ecto_typed_schema_typed {unquote(name), unquote(Macro.escape(typed))}

      if unquote(define_field) do
        @ecto_typed_schema_typed {unquote(foreign_key), unquote(Macro.escape(foreign_key_typed))}
      end

      Ecto.Schema.belongs_to(unquote(name), unquote(schema), unquote(opts))
    end
  end

  @spec has_one(atom(), module() | keyword(), keyword()) :: Macro.t()
  defmacro has_one(name, schema, opts \\ []) do
    {typed, schema, opts} = extract_has_typed_opts(schema, opts)
    typed = sanitize_typed_opts(typed)

    quote location: :keep do
      @ecto_typed_schema_typed {unquote(name), unquote(Macro.escape(typed))}

      Ecto.Schema.has_one(unquote(name), unquote(schema), unquote(opts))
    end
  end

  @spec embeds_one(atom(), module(), keyword()) :: Macro.t()
  defmacro embeds_one(name, schema, opts \\ []) do
    {typed, opts} = Keyword.pop(opts, :typed, [])
    typed = sanitize_typed_opts(typed)

    quote location: :keep do
      @ecto_typed_schema_typed {unquote(name), unquote(Macro.escape(typed))}

      Ecto.Schema.embeds_one(unquote(name), unquote(schema), unquote(opts))
    end
  end

  @spec embeds_one(atom(), module(), keyword(), keyword()) :: Macro.t()
  defmacro embeds_one(name, schema, opts, do: block) do
    schema = expand_nested_module_alias(schema, __CALLER__)
    {typed, opts} = Keyword.pop(opts, :typed, [])
    typed = sanitize_typed_opts(typed)

    quote location: :keep do
      @ecto_typed_schema_typed {unquote(name), unquote(Macro.escape(typed))}

      {schema, opts} =
        EctoTypedSchema.FieldMacros.create_inline_module(
          __ENV__,
          unquote(schema),
          unquote(opts),
          unquote(Macro.escape(block))
        )

      Ecto.Schema.__embeds_one__(__MODULE__, unquote(name), schema, opts)
    end
  end

  @spec embeds_many(atom(), module(), keyword()) :: Macro.t()
  defmacro embeds_many(name, schema, opts \\ []) do
    {typed, opts} = Keyword.pop(opts, :typed, [])
    typed = sanitize_typed_opts(typed)

    quote location: :keep do
      @ecto_typed_schema_typed {unquote(name), unquote(Macro.escape(typed))}

      Ecto.Schema.embeds_many(unquote(name), unquote(schema), unquote(opts))
    end
  end

  @spec embeds_many(atom(), module(), keyword(), keyword()) :: Macro.t()
  defmacro embeds_many(name, schema, opts, do: block) do
    schema = expand_nested_module_alias(schema, __CALLER__)
    {typed, opts} = Keyword.pop(opts, :typed, [])
    typed = sanitize_typed_opts(typed)

    quote location: :keep do
      @ecto_typed_schema_typed {unquote(name), unquote(Macro.escape(typed))}

      {schema, opts} =
        EctoTypedSchema.FieldMacros.create_inline_module(
          __ENV__,
          unquote(schema),
          unquote(opts),
          unquote(Macro.escape(block))
        )

      Ecto.Schema.__embeds_many__(__MODULE__, unquote(name), schema, opts)
    end
  end

  @spec has_many(atom(), module() | keyword(), keyword()) :: Macro.t()
  defmacro has_many(name, schema, opts \\ []) do
    {typed, schema, opts} = extract_has_typed_opts(schema, opts)
    typed = sanitize_typed_opts(typed)

    quote location: :keep do
      @ecto_typed_schema_typed {unquote(name), unquote(Macro.escape(typed))}

      Ecto.Schema.has_many(unquote(name), unquote(schema), unquote(opts))
    end
  end

  @spec many_to_many(atom(), module(), keyword()) :: Macro.t()
  defmacro many_to_many(name, schema, opts \\ []) do
    {typed, opts} = Keyword.pop(opts, :typed, [])
    typed = sanitize_typed_opts(typed)

    quote location: :keep do
      @ecto_typed_schema_typed {unquote(name), unquote(Macro.escape(typed))}

      Ecto.Schema.many_to_many(unquote(name), unquote(schema), unquote(opts))
    end
  end

  @spec timestamps(keyword()) :: Macro.t()
  defmacro timestamps(opts \\ []) do
    {typed, opts} = Keyword.pop(opts, :typed, [])
    typed = sanitize_typed_opts(typed)

    quote location: :keep do
      # Merge @timestamps_opts (if defined) with explicit opts.
      # Explicit opts take precedence over @timestamps_opts.
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

  # Extracts :typed opts and resolves :through for has_one/has_many.
  # When schema is a keyword list (through-association form like
  # `has_many :name, through: [...]`), :typed and :through live in schema.
  # Otherwise, :typed lives in opts.
  @spec extract_has_typed_opts(module() | keyword(), keyword()) ::
          {keyword(), module() | keyword(), keyword()}
  defp extract_has_typed_opts(schema, opts) do
    if is_list(schema) do
      {typed, schema} = Keyword.pop(schema, :typed, [])

      typed =
        if Keyword.has_key?(schema, :through), do: maybe_put_through(typed, schema), else: typed

      {typed, schema, opts}
    else
      {typed, opts} = Keyword.pop(opts, :typed, [])
      typed = if Keyword.has_key?(opts, :through), do: maybe_put_through(typed, opts), else: typed
      {typed, schema, opts}
    end
  end

  # Stores the `:through` path from Ecto opts into typed opts so
  # `__before_compile__` can detect through-associations.
  @spec maybe_put_through(keyword(), keyword()) :: keyword()
  defp maybe_put_through(typed, opts) do
    Keyword.put(typed, :through, Keyword.get(opts, :through))
  end

  @doc false
  @spec create_inline_module(Macro.Env.t(), module(), keyword(), Macro.t()) ::
          {module(), keyword()}
  def create_inline_module(env, module, opts, block) do
    {pk, opts} = Keyword.pop(opts, :primary_key, {:id, :binary_id, autogenerate: true})

    body =
      quote do
        use EctoTypedSchema

        @primary_key unquote(Macro.escape(pk))

        typed_embedded_schema do
          unquote(block)
        end
      end

    Module.create(module, body, env)
    {module, opts}
  end

  defp expand_nested_module_alias({:__aliases__, _, [Elixir | _] = alias}, _env),
    do: Module.concat(alias)

  defp expand_nested_module_alias({:__aliases__, _, [h | t]}, env) when is_atom(h),
    do: Module.concat([env.module, h | t])

  defp expand_nested_module_alias(other, _env), do: other
end
