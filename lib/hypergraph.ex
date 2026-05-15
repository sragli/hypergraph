defmodule Hypergraph do
  @moduledoc """
  A module for creating and manipulating hypergraphs.

  A hypergraph is a generalization of a graph where edges (hyperedges)
  can connect any number of vertices, not just two.
  """

  defstruct vertices: MapSet.new(), hyperedges: []

  @type vertex :: any()
  @type hyperedge :: [vertex()]
  @type t :: %__MODULE__{
          vertices: MapSet.t(vertex()),
          hyperedges: [hyperedge()]
        }

  @doc """
  Creates a new empty hypergraph.
  """
  @spec new() :: t()
  def new do
    %__MODULE__{}
  end

  @doc """
  Creates a new hypergraph with the given vertices and hyperedges.
  """
  @spec new([vertex()], [hyperedge()]) :: t()
  def new(vertices, hyperedges) do
    vertex_set = MapSet.new(vertices)

    # Ensure all vertices in hyperedges are in the vertex set
    all_hyperedge_vertices =
      hyperedges
      |> Enum.reduce(MapSet.new(), fn edge, acc -> MapSet.union(acc, MapSet.new(edge)) end)

    final_vertices = MapSet.union(vertex_set, all_hyperedge_vertices)

    %__MODULE__{
      vertices: final_vertices,
      hyperedges: hyperedges
    }
  end

  @doc """
  Adds a vertex to the hypergraph.
  """
  @spec add_vertex(t(), vertex()) :: t()
  def add_vertex(%__MODULE__{} = hypergraph, vertex) do
    %{hypergraph | vertices: MapSet.put(hypergraph.vertices, vertex)}
  end

  @doc """
  Adds multiple vertices to the hypergraph.
  """
  @spec add_vertices(t(), [vertex()]) :: t()
  def add_vertices(%__MODULE__{} = hypergraph, vertices) do
    new_vertices = MapSet.union(hypergraph.vertices, MapSet.new(vertices))
    %{hypergraph | vertices: new_vertices}
  end

  @doc """
  Adds a hyperedge to the hypergraph. The hyperedge connects all vertices in the given list.
  Automatically adds any new vertices to the hypergraph.
  """
  @spec add_hyperedge(t(), hyperedge()) :: t()
  def add_hyperedge(%__MODULE__{} = hypergraph, vertices) when is_list(vertices) do
    new_vertices = MapSet.union(hypergraph.vertices, MapSet.new(vertices))
    new_hyperedges = hypergraph.hyperedges ++ [vertices]

    %{hypergraph | vertices: new_vertices, hyperedges: new_hyperedges}
  end

  @doc """
  Removes a vertex from the hypergraph and all hyperedges containing it.
  """
  @spec remove_vertex(t(), vertex()) :: t()
  def remove_vertex(%__MODULE__{} = hypergraph, vertex) do
    new_vertices = MapSet.delete(hypergraph.vertices, vertex)

    # Remove vertex from each hyperedge and filter out empty hyperedges
    new_hyperedges =
      hypergraph.hyperedges
      |> Enum.map(&List.delete(&1, vertex))
      |> Enum.reject(&(&1 == []))

    %{hypergraph | vertices: new_vertices, hyperedges: new_hyperedges}
  end

  @doc """
  Removes a hyperedge from the hypergraph.
  """
  @spec remove_hyperedge(t(), hyperedge()) :: t()
  def remove_hyperedge(%__MODULE__{} = hypergraph, vertices) when is_list(vertices) do
    new_hyperedges = List.delete(hypergraph.hyperedges, vertices)
    %{hypergraph | hyperedges: new_hyperedges}
  end

  @doc """
  Returns all vertices in the hypergraph.
  """
  @spec vertices(t()) :: MapSet.t(vertex())
  def vertices(%__MODULE__{} = hypergraph) do
    hypergraph.vertices
  end

  @doc """
  Returns all hyperedges in the hypergraph.
  """
  @spec hyperedges(t()) :: [hyperedge()]
  def hyperedges(%__MODULE__{} = hypergraph) do
    hypergraph.hyperedges
  end

  @doc """
  Returns the degree of a vertex (number of hyperedges containing it).
  """
  @spec degree(t(), vertex()) :: non_neg_integer()
  def degree(%__MODULE__{} = hypergraph, vertex) do
    hypergraph.hyperedges
    |> Enum.count(&(vertex in &1))
  end

  @doc """
  Returns all vertices that share at least one hyperedge with the given vertex.
  """
  @spec neighbors(t(), vertex()) :: MapSet.t(vertex())
  def neighbors(%__MODULE__{} = hypergraph, vertex) do
    hypergraph.hyperedges
    |> Enum.filter(&(vertex in &1))
    |> Enum.reduce(MapSet.new(), fn edge, acc -> MapSet.union(acc, MapSet.new(edge)) end)
    |> MapSet.delete(vertex)
  end

  @doc """
  Returns hyperedges that contain the given vertex.
  """
  @spec incident_hyperedges(t(), vertex()) :: [hyperedge()]
  def incident_hyperedges(%__MODULE__{} = hypergraph, vertex) do
    hypergraph.hyperedges
    |> Enum.filter(&(vertex in &1))
  end

  @doc """
  Returns the size of a hyperedge (number of vertices it contains).
  """
  @spec hyperedge_size(hyperedge()) :: non_neg_integer()
  def hyperedge_size(hyperedge) when is_list(hyperedge) do
    length(hyperedge)
  end

  @doc """
  Checks if two vertices are connected by at least one hyperedge.
  """
  @spec connected?(t(), vertex(), vertex()) :: boolean()
  def connected?(%__MODULE__{} = hypergraph, vertex1, vertex2) do
    hypergraph.hyperedges
    |> Enum.any?(fn hyperedge ->
      vertex1 in hyperedge and vertex2 in hyperedge
    end)
  end

  @doc """
  Returns the number of vertices in the hypergraph.
  """
  @spec vertex_count(t()) :: non_neg_integer()
  def vertex_count(%__MODULE__{} = hypergraph) do
    MapSet.size(hypergraph.vertices)
  end

  @doc """
  Returns the number of hyperedges in the hypergraph.
  """
  @spec hyperedge_count(t()) :: non_neg_integer()
  def hyperedge_count(%__MODULE__{} = hypergraph) do
    length(hypergraph.hyperedges)
  end

  @doc """
  Converts the hypergraph to a regular graph by creating pairwise edges
  for every pair of vertices that share a hyperedge.

  Returns a list of 2-element tuples representing edges.
  """
  @spec to_graph(t()) :: [{vertex(), vertex()}]
  def to_graph(%__MODULE__{} = hypergraph) do
    hypergraph.hyperedges
    |> Enum.flat_map(fn hyperedge ->
      unique = Enum.uniq(hyperedge)
      for v1 <- unique, v2 <- unique, v1 < v2, do: {v1, v2}
    end)
    |> Enum.uniq()
  end

  @doc """
  Returns statistics about the hypergraph.
  """
  @spec stats(t()) :: map()
  def stats(%__MODULE__{} = hypergraph) do
    hyperedge_sizes = Enum.map(hypergraph.hyperedges, &length/1)
    degrees = Enum.map(hypergraph.vertices, &degree(hypergraph, &1))

    %{
      vertex_count: vertex_count(hypergraph),
      hyperedge_count: hyperedge_count(hypergraph),
      max_hyperedge_size: if(hyperedge_sizes == [], do: 0, else: Enum.max(hyperedge_sizes)),
      min_hyperedge_size: if(hyperedge_sizes == [], do: 0, else: Enum.min(hyperedge_sizes)),
      avg_hyperedge_size:
        if(hyperedge_sizes == [],
          do: 0,
          else: Enum.sum(hyperedge_sizes) / length(hyperedge_sizes)
        ),
      max_degree: if(degrees == [], do: 0, else: Enum.max(degrees)),
      min_degree: if(degrees == [], do: 0, else: Enum.min(degrees)),
      avg_degree: if(degrees == [], do: 0, else: Enum.sum(degrees) / length(degrees))
    }
  end
end
