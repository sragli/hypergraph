defmodule HypergraphTest do
  use ExUnit.Case
  doctest Hypergraph

  test "creates a simple hypergraph" do
    hg = Hypergraph.new()
    assert is_map(hg.vertices)
    assert hg.vertices == MapSet.new([])
    assert hg.hyperedges == MapSet.new([])
  end

  test "creates a hypergraph with two vertices and an edge between them" do
    hg =
      Hypergraph.new()
      |> Hypergraph.add_vertex(:one)
      |> Hypergraph.add_vertex(:two)
      |> Hypergraph.add_hyperedge([:one, :two])

    assert hg.vertices == MapSet.new([:one, :two])
    assert hg.hyperedges == MapSet.new([MapSet.new([:one, :two])])
  end

  test "removes an edge from a hypergraph" do
    hg =
      Hypergraph.new()
      |> Hypergraph.add_vertex(:one)
      |> Hypergraph.add_vertex(:two)
      |> Hypergraph.add_vertex(:three)
      |> Hypergraph.add_hyperedge([:one, :two])
      |> Hypergraph.add_hyperedge([:two, :three])
      |> Hypergraph.remove_hyperedge([:one, :two])

    assert hg.vertices == MapSet.new([:one, :two, :three])
    assert hg.hyperedges == MapSet.new([MapSet.new([:two, :three])])
  end

  test "computes degree of a vertex" do
    hg =
      Hypergraph.new()
      |> Hypergraph.add_vertex(:one)
      |> Hypergraph.add_vertex(:two)
      |> Hypergraph.add_hyperedge([:one, :two])
      |> Hypergraph.add_hyperedge([:two, :one])

    assert Hypergraph.degree(hg, :one) == 1
  end
end
