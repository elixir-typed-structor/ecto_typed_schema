defmodule TypeTestCase do
  @moduledoc """
  Test utilities for type testing, adapted from typed_structor's testing methodology.

  Provides utilities for:
  - Creating and cleaning up temporary modules for isolated testing
  - Extracting and comparing types from compiled modules
  - Testing struct behavior and type generation
  """

  use ExUnit.CaseTemplate
  import ExUnit.Assertions

  setup ctx do
    if Map.has_key?(ctx, :tmp_dir) do
      true = Code.append_path(ctx.tmp_dir)
      on_exit(fn -> Code.delete_path(ctx.tmp_dir) end)
    end

    :ok
  end

  using do
    quote do
      @moduletag :tmp_dir

      import unquote(__MODULE__)
    end
  end

  @doc """
  Creates a temporary module for testing, executes the given block,
  and returns the result of the after block.

  The module is automatically cleaned up after the test.

  ## Example

      test "type generation" do
        result = with_tmpmodule TestModule, %{tmp_dir: tmp_dir} do
          use EctoTypedSchema

          typed_schema "test" do
            field :name, :string
          end
        after
          fetch_types!(TestModule)
        end

        assert result == [t: 0]
      end
  """
  defmacro with_tmpmodule(module_name, ctx, options) when is_list(options) do
    module_name =
      module_name
      |> Macro.expand(__CALLER__)
      |> then(&Module.concat(__CALLER__.module, &1))

    body = Keyword.fetch!(options, :do)

    content =
      """
      defmodule #{inspect(module_name)} do
        #{aliases(__CALLER__)}

        #{Macro.to_string(body)}
      end
      """

    callback =
      quote do
        fn ->
          alias unquote(module_name)
          unquote(Keyword.get(options, :after))
        end
      end

    quote do
      unquote(__MODULE__).__with_file__(
        unquote(ctx),
        {unquote(module_name), unquote(content)},
        unquote(callback)
      )
    end
  end

  defmacro with_tmpmodule(module_name, ctx, do: body, after: after_block) do
    quote do
      with_tmpmodule(unquote(module_name), unquote(ctx),
        do: unquote(body),
        after: unquote(after_block)
      )
    end
  end

  defp aliases(env) do
    Enum.map_join(
      env.aliases,
      "\n",
      fn {alias_name, actual_module} ->
        """
        alias #{inspect(actual_module)}, as: #{inspect(alias_name)}
        _ = #{inspect(alias_name)}
        """
      end
    )
  end

  @doc false
  def __with_file__(%{tmp_dir: dir}, {module_name, content}, fun) when is_function(fun, 0) do
    path = Path.join([dir, "#{Atom.to_string(module_name)}.ex"])

    File.write!(path, content)
    mods = compile_file!(path, dir)

    try do
      fun.()
    after
      File.rm!(path)
      cleanup_modules(mods, dir)
    end
  end

  defp compile_file!(path, dir) do
    Code.compiler_options(docs: true, debug_info: true)

    case Kernel.ParallelCompiler.compile_to_path(List.wrap(path), dir, return_diagnostics: true) do
      {:ok, modules, _} ->
        modules

      {:error, [%{message: message, file: file, position: position} | _], _} ->
        raise CompileError, file: file, line: position, description: message

      {:error, [{file, position, message} | _], _} ->
        raise CompileError, file: file, line: position, description: message
    end
  end

  @doc """
  Extracts all types from a compiled module.

  Returns a list of {type_name, arity} tuples.
  """
  def fetch_types!(module) do
    module
    |> Code.Typespec.fetch_types()
    |> case do
      :error ->
        ExUnit.Assertions.flunk("Failed to fetch types for module #{module}")

      {:ok, types} ->
        types
    end
  end

  @doc """
  Asserts that the expected types are equal to the actual types by comparing
  their formatted strings.
  """
  def assert_type(expected, actual) do
    expected_types = format_types(expected)

    if String.length(String.trim(expected_types)) === 0 do
      ExUnit.Assertions.flunk("Expected types are empty: #{inspect(expected)}")
    end

    actual_types = format_types(actual)

    assert expected_types == actual_types
  end

  defp format_types(types) do
    types
    |> Enum.sort_by(fn {_, {name, _, args}} -> {name, length(args)} end)
    |> Enum.map_join(
      "\n",
      fn {kind, type} ->
        ast = Code.Typespec.type_to_quoted(type)
        "@#{kind} #{Macro.to_string(ast)}"
      end
    )
  end

  @doc """
  Cleans up the modules by removing the beam files and purging the code.
  """
  def cleanup_modules(mods, dir) do
    Enum.each(mods, fn mod ->
      File.rm(Path.join([dir, "#{mod}.beam"]))
      :code.purge(mod)
      true = :code.delete(mod)
    end)
  end
end
