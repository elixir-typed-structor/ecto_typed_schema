defmodule EctoTypedSchema.Types.PluginTest do
  use TypeTestCase, async: true

  @compile {:no_warn_undefined, __MODULE__.Schema}

  # Tracks callback invocations via module attributes.
  defmodule TrackingPlugin do
    use TypedStructor.Plugin

    @impl TypedStructor.Plugin
    defmacro init(_opts) do
      quote do
        Module.register_attribute(__MODULE__, :plugin_tracking, accumulate: true)
        @plugin_tracking :init_called
      end
    end

    @impl TypedStructor.Plugin
    defmacro before_definition(definition, _opts) do
      quote do
        @plugin_tracking :before_definition_called
        unquote(definition)
      end
    end

    @impl TypedStructor.Plugin
    defmacro after_definition(_definition, _opts) do
      quote do
        @plugin_tracking :after_definition_called
        def plugin_tracking, do: @plugin_tracking
      end
    end
  end

  # Stores its options for verification.
  defmodule OptsPlugin do
    use TypedStructor.Plugin

    @impl TypedStructor.Plugin
    defmacro init(opts) do
      quote do
        @plugin_opts unquote(opts)
        def plugin_opts, do: @plugin_opts
      end
    end
  end

  # Makes all fields non-nullable via before_definition.
  defmodule NonNullPlugin do
    use TypedStructor.Plugin

    @impl TypedStructor.Plugin
    defmacro before_definition(definition, _opts) do
      quote do
        Map.update!(unquote(definition), :fields, fn fields ->
          Enum.map(fields, fn field ->
            Keyword.put(field, :null, false)
          end)
        end)
      end
    end
  end

  # Second tracking plugin for multi-plugin ordering tests.
  defmodule SecondTrackingPlugin do
    use TypedStructor.Plugin

    @impl TypedStructor.Plugin
    defmacro init(_opts) do
      quote do
        Module.register_attribute(__MODULE__, :second_plugin_tracking, accumulate: true)
        @second_plugin_tracking :init_called
      end
    end

    @impl TypedStructor.Plugin
    defmacro after_definition(_definition, _opts) do
      quote do
        @second_plugin_tracking :after_definition_called
        def second_plugin_tracking, do: @second_plugin_tracking
      end
    end
  end

  describe "plugin callbacks" do
    test "all three callbacks are invoked", ctx do
      with_tmpmodule Schema, ctx do
        use EctoTypedSchema

        @primary_key false

        typed_embedded_schema do
          plugin EctoTypedSchema.Types.PluginTest.TrackingPlugin

          field :name, :string
        end
      after
        tracking = Schema.plugin_tracking()
        assert :init_called in tracking
        assert :before_definition_called in tracking
        assert :after_definition_called in tracking
      end
    end

    test "plugin receives options", ctx do
      with_tmpmodule Schema, ctx do
        use EctoTypedSchema

        @primary_key false

        typed_embedded_schema do
          plugin EctoTypedSchema.Types.PluginTest.OptsPlugin, foo: :bar, baz: 42

          field :name, :string
        end
      after
        assert Schema.plugin_opts() == [foo: :bar, baz: 42]
      end
    end
  end

  describe "before_definition modifies type output" do
    test "plugin setting all fields non-nullable changes the generated type", ctx do
      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          @primary_key false

          typed_embedded_schema do
            plugin EctoTypedSchema.Types.PluginTest.NonNullPlugin

            field :name, :string
            field :age, :integer
          end
        after
          fetch_types!(Schema)
        end

      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          @primary_key false

          embedded_schema do
            field :name, :string
            field :age, :integer
          end

          # NonNullPlugin adds null: false to all fields,
          # making them non-nullable in the generated type.
          @type t() :: %__MODULE__{
                  name: String.t(),
                  age: integer()
                }
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "plugin with typed_schema" do
    test "works alongside __meta__ field", ctx do
      generated_types =
        with_tmpmodule Schema, ctx do
          use EctoTypedSchema

          typed_schema "items" do
            plugin EctoTypedSchema.Types.PluginTest.TrackingPlugin

            field :name, :string
          end
        after
          fetch_types!(Schema)
        end

      expected_types =
        with_tmpmodule Schema, ctx do
          use Ecto.Schema

          schema "items" do
            field :name, :string
          end

          @type t() :: %__MODULE__{
                  __meta__: Ecto.Schema.Metadata.t(__MODULE__),
                  id: integer(),
                  name: String.t() | nil
                }
        after
          fetch_types!(Schema)
        end

      assert_type(expected_types, generated_types)
    end
  end

  describe "multiple plugins" do
    test "both plugins are invoked", ctx do
      with_tmpmodule Schema, ctx do
        use EctoTypedSchema

        @primary_key false

        typed_embedded_schema do
          plugin EctoTypedSchema.Types.PluginTest.TrackingPlugin
          plugin EctoTypedSchema.Types.PluginTest.SecondTrackingPlugin

          field :name, :string
        end
      after
        first = Schema.plugin_tracking()
        assert :init_called in first
        assert :before_definition_called in first
        assert :after_definition_called in first

        second = Schema.second_plugin_tracking()
        assert :init_called in second
        assert :after_definition_called in second
      end
    end
  end
end
