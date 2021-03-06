defmodule NewRelicEcto.MixProject do
  use Mix.Project

  def project do
    [
      app: :new_relic_ecto,
      description: "[Deprecated] Part of the `new_relic_agent` now",
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
      {:ecto_sql, "~> 3.0"},
      {:postgrex, ">= 0.0.0", only: :test}
    ]
  end
end
