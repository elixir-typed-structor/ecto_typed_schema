defmodule EctoTypedSchema.MixProject do
  use Mix.Project

  def project do
    [
      app: :ecto_typed_schema,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # FIXME: change back to hex package when published
      {:typed_structor,
       github: "elixir-typed-structor/typed_structor", branch: "feat/null-option-and-readme"},
      {:ecto, "~> 3.10"}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]
end
