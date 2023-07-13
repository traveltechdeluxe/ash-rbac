defmodule AshRbac.MixProject do
  use Mix.Project

  def project do
    [
      app: :ash_rbac,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ash, "~> 2.11.8"},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:elixir_uuid, "~> 1.2", only: [:test], runtime: false},
      {:git_hooks, "~> 0.7.3", only: :dev},
      # test watcher
      {:mix_test_watch, "~> 1.0", only: :dev, runtime: false}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
