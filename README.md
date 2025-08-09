# Hypergraph

Elixir module for working with hypergraphs.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `hypergraph` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:hypergraph, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/hypergraph>.

## Core Features

* Create new hypergraphs (empty or with initial data)
* Add/remove vertices and hyperedges
* Query hypergraph properties and relationships

## Key Functions

* `new/0` and `new/2` - Create hypergraphs
* `add_vertex/2`, `add_hyperedge/2` - Add elements
* `remove_vertex/2`, `remove_hyperedge/2` - Remove elements
* `degree/2` - Get vertex degree (number of hyperedges containing it)
* `neighbors/2` - Find vertices sharing hyperedges with a given vertex
* `connected?/3` - Check if two vertices share any hyperedges
* `to_graph/1` - Convert to regular graph with pairwise edges
* `stats/1` - Get comprehensive statistics

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

The module uses MapSets internally for efficient set operations and ensures data consistency
(vertices referenced in hyperedges are automatically added to the vertex set). It's designed
to be both functional and performant for typical hypergraph operations.