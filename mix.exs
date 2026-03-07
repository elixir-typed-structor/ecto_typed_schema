defmodule EctoTypedSchema.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/elixir-typed-structor/ecto_typed_schema"

  def project do
    [
      app: :ecto_typed_schema,
      elixir: "~> 1.17",
      description: "Auto-generate accurate @type t() specs from your Ecto schema definitions.",
      version: @version,
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: Mix.env() != :test,
      deps: deps(),
      name: "EctoTypedSchema",
      source_url: @source_url,
      homepage_url: @source_url,
      docs: [
        main: "readme",
        source_url: @source_url,
        source_ref: "v#{@version}",
        extras: [
          {"README.md", [title: "Introduction"]},
          "LICENSE"
        ],
        skip_undefined_reference_warnings_on: ["Ecto.Association"],
        groups_for_docs: [
          Schema: &(&1[:group] == "Schema"),
          "Fields and Associations": &(&1[:group] == "Fields and Associations"),
          "Type Customization": &(&1[:group] == "Type Customization")
        ]
      ],
      package: [
        name: "ecto_typed_schema",
        licenses: ["MIT"],
        links: %{
          "GitHub" => @source_url
        }
      ],
      dialyzer: [
        plt_add_apps: [:ex_unit]
      ],
      aliases: aliases()
    ]
  end

  def cli do
    [preferred_envs: [precommit: :test]]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:typed_structor, "~> 0.6"},
      {:ecto, "~> 3.10"},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp aliases do
    [
      precommit: [
        "format",
        "compile --warnings-as-errors",
        "dialyzer",
        "test"
      ]
    ]
  end
end
