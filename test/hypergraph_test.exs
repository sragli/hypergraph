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
      |> Hypergraph.add_vertices([:one, :two, :three])
      |> Hypergraph.add_hyperedge([:one, :two])
      |> Hypergraph.add_hyperedge([:two, :three])
      |> Hypergraph.remove_hyperedge([:one, :two])

    assert hg.vertices == MapSet.new([:one, :two, :three])
    assert hg.hyperedges == MapSet.new([MapSet.new([:two, :three])])
  end

  test "removes a vertex from a hypergraph" do
    hg =
      Hypergraph.new()
      |> Hypergraph.add_vertex(:one)
      |> Hypergraph.add_vertex(:two)
      |> Hypergraph.add_hyperedge([:one, :two])
      |> Hypergraph.remove_vertex(:two)

    assert hg.vertices == MapSet.new([:one])
    assert hg.hyperedges == MapSet.new([MapSet.new([:one])])
  end

  test "returns the number of vertices in a hypergraph" do
    hg =
      Hypergraph.new()
      |> Hypergraph.add_vertex(:one)
      |> Hypergraph.add_vertex(:two)

    assert Hypergraph.vertex_count(hg) == 2
    assert MapSet.size(Hypergraph.vertices(hg)) == 2
  end

  test "returns the number of edges in a hypergraph" do
    hg =
      Hypergraph.new()
      |> Hypergraph.add_vertex(:one)
      |> Hypergraph.add_vertex(:two)
      |> Hypergraph.add_hyperedge([:one, :two])
      |> Hypergraph.add_hyperedge([:one, :one])

    assert Hypergraph.hyperedge_count(hg) == 2
    assert MapSet.size(Hypergraph.hyperedges(hg)) == 2
  end

  test "computes the degree of a vertex" do
    hg =
      Hypergraph.new()
      |> Hypergraph.add_vertex(:one)
      |> Hypergraph.add_vertex(:two)
      |> Hypergraph.add_hyperedge([:one, :two])
      |> Hypergraph.add_hyperedge([:two, :one])

    assert Hypergraph.degree(hg, :one) == 1
  end

  test "calculates the number of neighbors of a vertex" do
    hg =
      Hypergraph.new()
      |> Hypergraph.add_vertices([:one, :two, :three])
      |> Hypergraph.add_hyperedge([:one, :two])

    assert Hypergraph.neighbors(hg, :one) == MapSet.new([:two])
  end

  test "checks if two vertices are connected" do
    hg =
      Hypergraph.new()
      |> Hypergraph.add_vertices([:one, :two, :three])
      |> Hypergraph.add_hyperedge([:one, :two])
      |> Hypergraph.add_hyperedge([:three, :two])

    assert Hypergraph.connected?(hg, :one, :two)
    assert Hypergraph.connected?(hg, :one, :three) == false
  end
end
