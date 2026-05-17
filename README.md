# Hypergraph

Elixir library for working with hypergraphs.

A hypergraph is a generalization of a regular graph where edges can connect more than two vertices at once.
In a regular graph, each edge connects exactly two vertices. But in a hypergraph, an edge (called a "hyperedge") can connect any number of vertices - it could connect 3, 4, 5, or even all vertices in the hypergraph simultaneously.

Mathematically, a hypergraph `H` is defined as an ordered pair `(V, E)` where `V` is a set of vertices and `E` is a set of hyperedges, with each hyperedge being a non-empty subset of `V`.

Hypergraphs are particularly useful for modeling complex relationships that involve multiple entities at once — such as social groups, chemical reactions, collaborative networks, and more.

## Installation

Add `hypergraph` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:hypergraph, "~> 1.0.0"}
  ]
end
```

## Modules

* [`Hypergraph`](https://hexdocs.pm/hypergraph/Hypergraph.html) — Create, update, and query hypergraphs
* [`Hypergraph.CorrelationLength`](https://hexdocs.pm/hypergraph/Hypergraph.CorrelationLength.html) — Measure how far structural information propagates using Mutual Information decay
* [`Hypergraph.NetworkGraph`](https://hexdocs.pm/hypergraph/Hypergraph.NetworkGraph.html) — Render a hypergraph as a VegaLite network graph

## Usage

### Building a hypergraph

```elixir
hg =
  Hypergraph.new()
  |> Hypergraph.add_hyperedge([:alice, :bob, :charlie])  # 3-way connection
  |> Hypergraph.add_hyperedge([:bob, :diana])            # 2-way connection
  |> Hypergraph.add_hyperedge([:diana, :eve, :frank])    # another group
```

### Querying

```elixir
Hypergraph.vertices(hg)                        #=> MapSet of all vertices
Hypergraph.hyperedges(hg)                      #=> list of all hyperedges
Hypergraph.degree(hg, :bob)                    #=> number of hyperedges containing :bob
Hypergraph.neighbors(hg, :alice)               #=> vertices sharing a hyperedge with :alice
Hypergraph.incident_hyperedges(hg, :bob)       #=> hyperedges that contain :bob
Hypergraph.connected?(hg, :alice, :charlie)    #=> true if they share a hyperedge
Hypergraph.vertex_count(hg)                    #=> total number of vertices
Hypergraph.hyperedge_count(hg)                 #=> total number of hyperedges
```

### Statistics

```elixir
Hypergraph.stats(hg)
# %{
#   vertex_count: 5,
#   hyperedge_count: 3,
#   max_hyperedge_size: 3,
#   min_hyperedge_size: 2,
#   avg_hyperedge_size: 2.67,
#   max_degree: 2,
#   min_degree: 1,
#   avg_degree: 1.4
# }
```

### Modifying a hypergraph

```elixir
hg = Hypergraph.remove_vertex(hg, :eve)           # remove vertex and its hyperedges
hg = Hypergraph.remove_hyperedge(hg, [:bob, :diana])
```

### Converting to a regular graph

```elixir
# Returns pairwise edges for every pair of vertices sharing a hyperedge
Hypergraph.to_graph(hg)
#=> [{:alice, :bob}, {:alice, :charlie}, {:bob, :charlie}, ...]
```

### Correlation Length

Measures how far structural information propagates through the hypergraph by fitting an exponential decay curve to Mutual Information values between distant regions.

```elixir
{:ok, length} = Hypergraph.CorrelationLength.compute(hg)
# length is a float representing the characteristic decay distance

# With custom parameters:
{:ok, length} = Hypergraph.CorrelationLength.compute(hg,
  _max_distance = 15,
  _region_size = 3,
  _samples = 200
)
```

Possible error returns: `:insufficient_data`, `:insufficient_points`, `:insufficient_positive_data`, `:no_decay`, `:singular_matrix`.

### Visualization

Renders the hypergraph as an interactive VegaLite network graph. Vertices are arranged in a circular layout; node size and color reflect vertex degree.

```elixir
# In a Livebook or any environment with kino_vega_lite:
Hypergraph.NetworkGraph.visualize(hg)
```

See `examples.livemd` for runnable Livebook examples including social network and chemical reaction hypergraphs.

## License

Apache 2.0 — see [LICENSE](LICENSE).