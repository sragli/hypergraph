defmodule Hypergraph.NetworkGraphTest do
  use ExUnit.Case, async: true

  alias Hypergraph
  alias Hypergraph.NetworkGraph

  test "visualize handles empty hypergraph" do
    hg = Hypergraph.new()

    spec = VegaLite.to_spec(NetworkGraph.visualize(hg))
    layers = spec["layer"]

    assert is_list(layers)

    circle = Enum.find(layers, fn l -> l["mark"]["type"] == "circle" end)
    assert circle["data"]["values"] == []
  end

  test "single vertex has correct degree and size" do
    hg = Hypergraph.new([:a], [])

    spec = VegaLite.to_spec(NetworkGraph.visualize(hg))
    layers = spec["layer"]
    circle = Enum.find(layers, fn l -> l["mark"]["type"] == "circle" end)
    values = circle["data"]["values"]

    assert length(values) == 1

    node = hd(values)
    assert node["id"] == :a
    assert node["degree"] == 0
    assert node["size"] == 100
  end
end
