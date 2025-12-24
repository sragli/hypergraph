defmodule Hypergraph.MixProject do
  use Mix.Project

  def project do
    [
      app: :hypergraph,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps(),
      name: "Hypergraph",
      source_url: "https://github.com/sragli/hypergraph",
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp description() do
    "Elixir module for working with hypergraphs."
  end

  defp package() do
    [
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE CHANGELOG),
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/sragli/hypergraph"}
    ]
  end

  defp docs() do
    [
      main: "Hypergraph",
      extras: ["README.md", "LICENSE", "examples.livemd"]
    ]
  end

  defp deps do
    [
      {:vega_lite, "~> 0.1"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end
end
