defmodule NewRelicEcto.MixProject do
  use Mix.Project

  def project do
    [
      app: :new_relic_ecto,
      description: "New Relic Instrumentation adapter for Ecto",
      version: "0.0.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      name: "New Relic Ecto",
      package: package(),
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp package do
    [
      maintainers: ["Vince Foley"],
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => "https://github.com/binaryseed/new_relic_ecto"}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev},
      {:new_relic_agent, "~> 1.14"},
      {:ecto, "~> 3.3"},
      {:ecto_sql, "~> 3.3"},
      {:telemetry, "~> 0.4"},
      {:postgrex, ">= 0.0.0", only: :test, optional: true}
    ]
  end
end
