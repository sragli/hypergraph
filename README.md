# Hypergraph

Elixir library for working with hypergraphs.

A hypergraph is a generalization of a regular graph where edges can connect more than two
vertices at once.
In a regular graph, each edge connects exactly two vertices. But in a hypergraph, an edge
(called a "hyperedge") can connect any number of vertices - it could connect 3, 4, 5, or
even all vertices in the hypergraph simultaneously.

Mathematically, a hypergraph `H` is defined as an ordered pair `(V, E)` where `V` is a set of
vertices and `E` is a set of hyperedges, with each hyperedge being a non-empty subset of `V`.

Hypergraphs are particularly useful for modeling complex relationships that involve multiple
entities at once.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed by adding
`hypergraph` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:hypergraph, "~> 0.2.0"}
  ]
end
```

## Core Features

* `Hypergraph` - Create, update and query hypergraphs
* `CorrelationLength` - Measure Correlation Length (how far structural information propagates) in a hypergraph
* `NetworkGraph` - Create a VegaLite-based network graph representation from a hypergraph

## Usage Examples

```elixir
# Create a hypergraph
hg = Hypergraph.new()

# Add vertices and hyperedges
hg = hg
     |> Hypergraph.add_hyperedge([:alice, :bob, :charlie])  # 3-way connection
     |> Hypergraph.add_hyperedge([:bob, :diana])            # 2-way connection
     |> Hypergraph.add_vertex(:eve)                         # Isolated vertex

# Query the hypergraph
Hypergraph.degree(hg, :bob)                    # How many hyperedges contain Bob?
Hypergraph.neighbors(hg, :alice)               # Who shares hyperedges with Alice?
Hypergraph.connected?(hg, :alice, :charlie)    # Are Alice and Charlie connected?
Hypergraph.stats(hg)
```