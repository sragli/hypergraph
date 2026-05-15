defmodule HypergraphTest do
  use ExUnit.Case
  doctest Hypergraph

  test "creates a simple hypergraph" do
    hg = Hypergraph.new()
    assert Hypergraph.vertices(hg) == MapSet.new([])
    assert hg.hyperedges == []
  end

  test "creates a hypergraph with two vertices and an edge between them" do
    hg =
      Hypergraph.new()
      |> Hypergraph.add_hyperedge([:one, :two])

    assert Hypergraph.vertices(hg) == MapSet.new([:one, :two])
    assert hg.hyperedges == [[:one, :two]]
  end

  test "removes an edge from a hypergraph" do
    hg =
      Hypergraph.new()
      |> Hypergraph.add_hyperedge([:one, :two])
      |> Hypergraph.add_hyperedge([:two, :three])
      |> Hypergraph.remove_hyperedge([:one, :two])

    assert Hypergraph.vertices(hg) == MapSet.new([:two, :three])
    assert hg.hyperedges == [[:two, :three]]
  end

  test "removes a vertex from a hypergraph" do
    hg =
      Hypergraph.new()
      |> Hypergraph.add_hyperedge([:one, :two])
      |> Hypergraph.remove_vertex(:two)

    assert Hypergraph.vertices(hg) == MapSet.new([:one])
    assert hg.hyperedges == [[:one]]
  end

  test "returns the number of vertices in a hypergraph" do
    hg =
      Hypergraph.new()
      |> Hypergraph.add_hyperedge([:one, :two])

    assert Hypergraph.vertex_count(hg) == 2
    assert MapSet.size(Hypergraph.vertices(hg)) == 2
  end

  test "returns the number of edges in a hypergraph" do
    hg =
      Hypergraph.new()
      |> Hypergraph.add_hyperedge([:one, :two])
      |> Hypergraph.add_hyperedge([:one, :one])

    assert Hypergraph.hyperedge_count(hg) == 2
    assert length(Hypergraph.hyperedges(hg)) == 2
  end

  test "computes the degree of a vertex" do
    hg =
      Hypergraph.new()
      |> Hypergraph.add_hyperedge([:one, :two])
      |> Hypergraph.add_hyperedge([:two, :one])

    assert Hypergraph.degree(hg, :one) == 2
  end

  test "calculates the number of neighbors of a vertex" do
    hg =
      Hypergraph.new()
      |> Hypergraph.add_hyperedge([:one, :two])

    assert Hypergraph.neighbors(hg, :one) == MapSet.new([:two])
  end

  test "checks if two vertices are connected" do
    hg =
      Hypergraph.new()
      |> Hypergraph.add_hyperedge([:one, :two])
      |> Hypergraph.add_hyperedge([:three, :two])

    assert Hypergraph.connected?(hg, :one, :two)
    assert Hypergraph.connected?(hg, :one, :three) == false
  end
end
