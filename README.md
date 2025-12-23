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
    {:hypergraph, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/hypergraph>.

## Core Features

* `Hypergraph` - Create, update and query hypergraphs
* `CorrelationLength` - Measure Correlation Length (how far structural information propagates) in a hypergraph
* `WolframCausalGraph` - Create Wolfram-style causal graph from scratch or by transforming a hypergraph

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

# Transform the hypergraph to a causal graph
cg = WolframCausalGraph.from_hypergraph(hg)

# Create a new causal graph
cg = WolframCausalGraph.new()

# Add events
cg = cg
      |> WolframCausalGraph.add_event(:e1, %{rule: :rule_a, timestamp: 0})
      |> WolframCausalGraph.add_event(:e2, %{rule: :rule_b, timestamp: 1})
      |> WolframCausalGraph.add_event(:e3, %{rule: :rule_a, timestamp: 2})

# Add causal dependencies (e2 depends on e1, e3 depends on e2)
cg = cg
      |> WolframCausalGraph.add_dependency(:e1, :e2)
      |> WolframCausalGraph.add_dependency(:e2, :e3)

# Query the causal graph
WolframCausalGraph.ancestors(cg, :e3)  # [:e1, :e2]
WolframCausalGraph.is_causal_predecessor?(cg, :e1, :e3)  # true
WolframCausalGraph.causal_depth(cg, :e3)  # 2

# Visualize the causal graph
WolframCausalGraph.to_dot()  # DOT digraph
WolframCausalGraph.to_svg()  # SVG source
```