defmodule Hypergraph.WolframCausalGraph do
  @moduledoc """
  An Elixir module for working with causal graphs in Wolfram Models.

  A causal graph represents the causal dependencies between update events in a
  Wolfram Model evolution. Each vertex represents an update event, and directed
  edges represent causal dependencies where one event must happen before another.

  In Wolfram Models, the causal graph captures the partial ordering of events that
  arise from the application of rewrite rules to a hypergraph. Unlike the spatial
  hypergraph that tracks the structure being rewritten, the causal graph tracks
  the relationships between the rewriting events themselves.

  ## Structure

  A causal graph is represented as:
  - `events`: A MapSet of event IDs (vertices)
  - `dependencies`: A map from event ID to a MapSet of events it depends on
  - `dependents`: A map from event ID to a MapSet of events that depend on it
  - `event_data`: A map from event ID to metadata about the event

  ## Examples

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

      # Query the graph
      WolframCausalGraph.ancestors(cg, :e3)  # [:e1, :e2]
      WolframCausalGraph.is_causal_predecessor?(cg, :e1, :e3)  # true
      WolframCausalGraph.causal_depth(cg, :e3)  # 2
  """
  alias Hypergraph

  defstruct events: MapSet.new(),
            dependencies: %{},
            dependents: %{},
            event_data: %{}

  @type event_id :: any()
  @type event_metadata :: map()
  @type t :: %__MODULE__{
          events: MapSet.t(event_id()),
          dependencies: %{event_id() => MapSet.t(event_id())},
          dependents: %{event_id() => MapSet.t(event_id())},
          event_data: %{event_id() => event_metadata()}
        }

  ## Construction

  @doc """
  Creates a new empty causal graph.

  ## Examples

      iex> cg = WolframCausalGraph.new()
      iex> WolframCausalGraph.event_count(cg)
      0
  """
  @spec new() :: t()
  def new do
    %__MODULE__{}
  end

  @doc """
  Creates a new causal graph with initial events and dependencies.

  ## Examples

      iex> events = [
      ...>   {:e1, %{rule: :r1}},
      ...>   {:e2, %{rule: :r2}}
      ...> ]
      iex> deps = [{:e1, :e2}]
      iex> cg = WolframCausalGraph.new(events, deps)
      iex> WolframCausalGraph.event_count(cg)
      2
  """
  @spec new([{event_id(), event_metadata()}], [{event_id(), event_id()}]) :: t()
  def new(events, dependencies \\ []) do
    cg = new()

    cg =
      Enum.reduce(events, cg, fn {event_id, metadata}, acc ->
        add_event(acc, event_id, metadata)
      end)

    Enum.reduce(dependencies, cg, fn {from, to}, acc ->
      add_dependency(acc, from, to)
    end)
  end

  @doc """
  Builds a causal graph from a `Hypergraph`, treating each vertex as an event.

  Behavior:
  - Every vertex in the hypergraph becomes an event in the causal graph.
  - For each hyperedge, vertices are deterministically ordered via `Enum.sort/1`.
    For each ordered pair with earlier < later, a directed dependency is added
    from the earlier vertex to the later vertex.
  """
  @spec from_hypergraph(Hypergraph.t()) :: t()
  def from_hypergraph(%Hypergraph{} = hg) do
    # Start with all vertices as events
    cg =
      Hypergraph.vertices(hg)
      |> Enum.reduce(new(), fn v, acc -> add_event(acc, v) end)

    # For each hyperedge, add directed dependencies from earlier -> later
    Enum.reduce(Hypergraph.hyperedges(hg), cg, fn hyperedge, acc ->
      vertices = hyperedge |> MapSet.to_list() |> Enum.sort()

      pairs =
        for {from, i} <- Enum.with_index(vertices),
            {to, j} <- Enum.with_index(vertices),
            i < j,
            do: {from, to}

      Enum.reduce(pairs, acc, fn {from, to}, acc2 -> add_dependency(acc2, from, to) end)
    end)
  end

  ## Modification

  @doc """
  Adds an event to the causal graph.

  ## Examples

      iex> cg = WolframCausalGraph.new()
      iex> cg = WolframCausalGraph.add_event(cg, :e1, %{rule: :rule_a})
      iex> WolframCausalGraph.has_event?(cg, :e1)
      true
  """
  @spec add_event(t(), event_id(), event_metadata()) :: t()
  def add_event(%__MODULE__{} = cg, event_id, metadata \\ %{}) do
    %{
      cg
      | events: MapSet.put(cg.events, event_id),
        event_data: Map.put(cg.event_data, event_id, metadata)
    }
  end

  @doc """
  Adds a causal dependency between two events.
  The `from` event must occur before the `to` event.

  Both events must already exist in the graph.

  ## Examples

      iex> cg = WolframCausalGraph.new()
      iex> cg = cg
      ...>   |> WolframCausalGraph.add_event(:e1)
      ...>   |> WolframCausalGraph.add_event(:e2)
      ...>   |> WolframCausalGraph.add_dependency(:e1, :e2)
      iex> WolframCausalGraph.is_causal_predecessor?(cg, :e1, :e2)
      true
  """
  @spec add_dependency(t(), event_id(), event_id()) :: t()
  def add_dependency(%__MODULE__{} = cg, from, to) do
    unless has_event?(cg, from) and has_event?(cg, to) do
      raise ArgumentError, "Both events must exist in the graph"
    end

    %{
      cg
      | dependencies: Map.update(cg.dependencies, to, MapSet.new([from]), &MapSet.put(&1, from)),
        dependents: Map.update(cg.dependents, from, MapSet.new([to]), &MapSet.put(&1, to))
    }
  end

  @doc """
  Removes an event and all its associated dependencies from the causal graph.

  ## Examples

      iex> cg = WolframCausalGraph.new()
      iex> cg = cg
      ...>   |> WolframCausalGraph.add_event(:e1)
      ...>   |> WolframCausalGraph.add_event(:e2)
      ...>   |> WolframCausalGraph.add_dependency(:e1, :e2)
      iex> cg = WolframCausalGraph.remove_event(cg, :e1)
      iex> WolframCausalGraph.has_event?(cg, :e1)
      false
  """
  @spec remove_event(t(), event_id()) :: t()
  def remove_event(%__MODULE__{} = cg, event_id) do
    # Remove from dependents of predecessors
    predecessors = Map.get(cg.dependencies, event_id, MapSet.new())

    dependents =
      Enum.reduce(predecessors, cg.dependents, fn pred, acc ->
        Map.update(acc, pred, MapSet.new(), &MapSet.delete(&1, event_id))
      end)

    # Remove from dependencies of successors
    successors = Map.get(cg.dependents, event_id, MapSet.new())

    dependencies =
      Enum.reduce(successors, cg.dependencies, fn succ, acc ->
        Map.update(acc, succ, MapSet.new(), &MapSet.delete(&1, event_id))
      end)

    %{
      cg
      | events: MapSet.delete(cg.events, event_id),
        dependencies: Map.delete(dependencies, event_id),
        dependents: Map.delete(dependents, event_id),
        event_data: Map.delete(cg.event_data, event_id)
    }
  end

  @doc """
  Removes a causal dependency between two events.

  ## Examples

      iex> cg = WolframCausalGraph.new()
      iex> cg = cg
      ...>   |> WolframCausalGraph.add_event(:e1)
      ...>   |> WolframCausalGraph.add_event(:e2)
      ...>   |> WolframCausalGraph.add_dependency(:e1, :e2)
      iex> cg = WolframCausalGraph.remove_dependency(cg, :e1, :e2)
      iex> WolframCausalGraph.is_causal_predecessor?(cg, :e1, :e2)
      false
  """
  @spec remove_dependency(t(), event_id(), event_id()) :: t()
  def remove_dependency(%__MODULE__{} = cg, from, to) do
    %{
      cg
      | dependencies: Map.update(cg.dependencies, to, MapSet.new(), &MapSet.delete(&1, from)),
        dependents: Map.update(cg.dependents, from, MapSet.new(), &MapSet.delete(&1, to))
    }
  end

  ## Queries

  @doc """
  Checks if an event exists in the causal graph.

  ## Examples

      iex> cg = WolframCausalGraph.new()
      iex> cg = WolframCausalGraph.add_event(cg, :e1)
      iex> WolframCausalGraph.has_event?(cg, :e1)
      true
      iex> WolframCausalGraph.has_event?(cg, :e2)
      false
  """
  @spec has_event?(t(), event_id()) :: boolean()
  def has_event?(%__MODULE__{} = cg, event_id) do
    MapSet.member?(cg.events, event_id)
  end

  @doc """
  Returns the number of events in the causal graph.

  ## Examples

      iex> cg = WolframCausalGraph.new()
      iex> cg = cg
      ...>   |> WolframCausalGraph.add_event(:e1)
      ...>   |> WolframCausalGraph.add_event(:e2)
      iex> WolframCausalGraph.event_count(cg)
      2
  """
  @spec event_count(t()) :: non_neg_integer()
  def event_count(%__MODULE__{} = cg) do
    MapSet.size(cg.events)
  end

  @doc """
  Returns the number of causal dependencies in the graph.

  ## Examples

      iex> cg = WolframCausalGraph.new()
      iex> cg = cg
      ...>   |> WolframCausalGraph.add_event(:e1)
      ...>   |> WolframCausalGraph.add_event(:e2)
      ...>   |> WolframCausalGraph.add_dependency(:e1, :e2)
      iex> WolframCausalGraph.dependency_count(cg)
      1
  """
  @spec dependency_count(t()) :: non_neg_integer()
  def dependency_count(%__MODULE__{} = cg) do
    cg.dependencies
    |> Map.values()
    |> Enum.map(&MapSet.size/1)
    |> Enum.sum()
  end

  @doc """
  Returns the immediate predecessors (direct dependencies) of an event.

  ## Examples

      iex> cg = WolframCausalGraph.new()
      iex> cg = cg
      ...>   |> WolframCausalGraph.add_event(:e1)
      ...>   |> WolframCausalGraph.add_event(:e2)
      ...>   |> WolframCausalGraph.add_event(:e3)
      ...>   |> WolframCausalGraph.add_dependency(:e1, :e3)
      ...>   |> WolframCausalGraph.add_dependency(:e2, :e3)
      iex> WolframCausalGraph.immediate_predecessors(cg, :e3) |> Enum.sort()
      [:e1, :e2]
  """
  @spec immediate_predecessors(t(), event_id()) :: [event_id()]
  def immediate_predecessors(%__MODULE__{} = cg, event_id) do
    cg.dependencies
    |> Map.get(event_id, MapSet.new())
    |> MapSet.to_list()
  end

  @doc """
  Returns the immediate successors (direct dependents) of an event.

  ## Examples

      iex> cg = WolframCausalGraph.new()
      iex> cg = cg
      ...>   |> WolframCausalGraph.add_event(:e1)
      ...>   |> WolframCausalGraph.add_event(:e2)
      ...>   |> WolframCausalGraph.add_event(:e3)
      ...>   |> WolframCausalGraph.add_dependency(:e1, :e2)
      ...>   |> WolframCausalGraph.add_dependency(:e1, :e3)
      iex> WolframCausalGraph.immediate_successors(cg, :e1) |> Enum.sort()
      [:e2, :e3]
  """
  @spec immediate_successors(t(), event_id()) :: [event_id()]
  def immediate_successors(%__MODULE__{} = cg, event_id) do
    cg.dependents
    |> Map.get(event_id, MapSet.new())
    |> MapSet.to_list()
  end

  @doc """
  Returns all ancestors (transitive dependencies) of an event.
  These are all events that must occur before the given event.

  ## Examples

      iex> cg = WolframCausalGraph.new()
      iex> cg = cg
      ...>   |> WolframCausalGraph.add_event(:e1)
      ...>   |> WolframCausalGraph.add_event(:e2)
      ...>   |> WolframCausalGraph.add_event(:e3)
      ...>   |> WolframCausalGraph.add_dependency(:e1, :e2)
      ...>   |> WolframCausalGraph.add_dependency(:e2, :e3)
      iex> WolframCausalGraph.ancestors(cg, :e3) |> Enum.sort()
      [:e1, :e2]
  """
  @spec ancestors(t(), event_id()) :: [event_id()]
  def ancestors(%__MODULE__{} = cg, event_id) do
    find_ancestors(cg, [event_id], MapSet.new())
    |> MapSet.to_list()
  end

  defp find_ancestors(_cg, [], visited), do: visited

  defp find_ancestors(cg, [current | rest], visited) do
    predecessors = immediate_predecessors(cg, current)
    new_predecessors = Enum.reject(predecessors, &MapSet.member?(visited, &1))
    new_visited = Enum.reduce(new_predecessors, visited, &MapSet.put(&2, &1))
    find_ancestors(cg, new_predecessors ++ rest, new_visited)
  end

  @doc """
  Returns all descendants (transitive dependents) of an event.
  These are all events that depend on the given event occurring.

  ## Examples

      iex> cg = WolframCausalGraph.new()
      iex> cg = cg
      ...>   |> WolframCausalGraph.add_event(:e1)
      ...>   |> WolframCausalGraph.add_event(:e2)
      ...>   |> WolframCausalGraph.add_event(:e3)
      ...>   |> WolframCausalGraph.add_dependency(:e1, :e2)
      ...>   |> WolframCausalGraph.add_dependency(:e2, :e3)
      iex> WolframCausalGraph.descendants(cg, :e1) |> Enum.sort()
      [:e2, :e3]
  """
  @spec descendants(t(), event_id()) :: [event_id()]
  def descendants(%__MODULE__{} = cg, event_id) do
    find_descendants(cg, [event_id], MapSet.new())
    |> MapSet.to_list()
  end

  defp find_descendants(_cg, [], visited), do: visited

  defp find_descendants(cg, [current | rest], visited) do
    successors = immediate_successors(cg, current)
    new_successors = Enum.reject(successors, &MapSet.member?(visited, &1))
    new_visited = Enum.reduce(new_successors, visited, &MapSet.put(&2, &1))
    find_descendants(cg, new_successors ++ rest, new_visited)
  end

  @doc """
  Checks if one event is a causal predecessor of another.
  Returns true if `from` must occur before `to` in the causal order.

  ## Examples

      iex> cg = WolframCausalGraph.new()
      iex> cg = cg
      ...>   |> WolframCausalGraph.add_event(:e1)
      ...>   |> WolframCausalGraph.add_event(:e2)
      ...>   |> WolframCausalGraph.add_event(:e3)
      ...>   |> WolframCausalGraph.add_dependency(:e1, :e2)
      ...>   |> WolframCausalGraph.add_dependency(:e2, :e3)
      iex> WolframCausalGraph.is_causal_predecessor?(cg, :e1, :e3)
      true
      iex> WolframCausalGraph.is_causal_predecessor?(cg, :e3, :e1)
      false
  """
  @spec is_causal_predecessor?(t(), event_id(), event_id()) :: boolean()
  def is_causal_predecessor?(%__MODULE__{} = cg, from, to) do
    from in ancestors(cg, to)
  end

  @doc """
  Returns the in-degree (number of immediate predecessors) of an event.

  ## Examples

      iex> cg = WolframCausalGraph.new()
      iex> cg = cg
      ...>   |> WolframCausalGraph.add_event(:e1)
      ...>   |> WolframCausalGraph.add_event(:e2)
      ...>   |> WolframCausalGraph.add_event(:e3)
      ...>   |> WolframCausalGraph.add_dependency(:e1, :e3)
      ...>   |> WolframCausalGraph.add_dependency(:e2, :e3)
      iex> WolframCausalGraph.in_degree(cg, :e3)
      2
  """
  @spec in_degree(t(), event_id()) :: non_neg_integer()
  def in_degree(%__MODULE__{} = cg, event_id) do
    cg.dependencies
    |> Map.get(event_id, MapSet.new())
    |> MapSet.size()
  end

  @doc """
  Returns the out-degree (number of immediate successors) of an event.

  ## Examples

      iex> cg = WolframCausalGraph.new()
      iex> cg = cg
      ...>   |> WolframCausalGraph.add_event(:e1)
      ...>   |> WolframCausalGraph.add_event(:e2)
      ...>   |> WolframCausalGraph.add_event(:e3)
      ...>   |> WolframCausalGraph.add_dependency(:e1, :e2)
      ...>   |> WolframCausalGraph.add_dependency(:e1, :e3)
      iex> WolframCausalGraph.out_degree(cg, :e1)
      2
  """
  @spec out_degree(t(), event_id()) :: non_neg_integer()
  def out_degree(%__MODULE__{} = cg, event_id) do
    cg.dependents
    |> Map.get(event_id, MapSet.new())
    |> MapSet.size()
  end

  @doc """
  Returns the causal depth (maximum path length from sources) of an event.
  Source events have depth 0.

  ## Examples

      iex> cg = WolframCausalGraph.new()
      iex> cg = cg
      ...>   |> WolframCausalGraph.add_event(:e1)
      ...>   |> WolframCausalGraph.add_event(:e2)
      ...>   |> WolframCausalGraph.add_event(:e3)
      ...>   |> WolframCausalGraph.add_dependency(:e1, :e2)
      ...>   |> WolframCausalGraph.add_dependency(:e2, :e3)
      iex> WolframCausalGraph.causal_depth(cg, :e3)
      2
  """
  @spec causal_depth(t(), event_id()) :: non_neg_integer()
  def causal_depth(%__MODULE__{} = cg, event_id) do
    {depth, _depths} = compute_depth(cg, event_id, %{})
    depth
  end

  defp compute_depth(_cg, event_id, depths) when is_map_key(depths, event_id) do
    case Map.get(depths, event_id) do
      :visiting ->
        raise ArgumentError,
              "Cycle detected in causal graph when computing depth for #{inspect(event_id)}"

      depth ->
        {depth, depths}
    end
  end

  defp compute_depth(cg, event_id, depths) do
    predecessors = immediate_predecessors(cg, event_id)

    cond do
      predecessors == [] ->
        {0, Map.put(depths, event_id, 0)}

      true ->
        # mark as visiting to detect cycles
        depths = Map.put(depths, event_id, :visiting)

        {max_predecessor_depth, depths} =
          Enum.reduce(predecessors, {0, depths}, fn pred, {acc_max, acc_depths} ->
            {d, acc_depths} = compute_depth(cg, pred, acc_depths)
            {Kernel.max(acc_max, d), acc_depths}
          end)

        depth = max_predecessor_depth + 1
        {depth, Map.put(depths, event_id, depth)}
    end
  end

  @doc """
  Returns all source events (events with no predecessors).

  ## Examples

      iex> cg = WolframCausalGraph.new()
      iex> cg = cg
      ...>   |> WolframCausalGraph.add_event(:e1)
      ...>   |> WolframCausalGraph.add_event(:e2)
      ...>   |> WolframCausalGraph.add_event(:e3)
      ...>   |> WolframCausalGraph.add_dependency(:e1, :e3)
      iex> WolframCausalGraph.source_events(cg) |> Enum.sort()
      [:e1, :e2]
  """
  @spec source_events(t()) :: [event_id()]
  def source_events(%__MODULE__{} = cg) do
    cg.events
    |> Enum.filter(fn event_id -> in_degree(cg, event_id) == 0 end)
  end

  @doc """
  Returns all sink events (events with no successors).

  ## Examples

      iex> cg = WolframCausalGraph.new()
      iex> cg = cg
      ...>   |> WolframCausalGraph.add_event(:e1)
      ...>   |> WolframCausalGraph.add_event(:e2)
      ...>   |> WolframCausalGraph.add_event(:e3)
      ...>   |> WolframCausalGraph.add_dependency(:e1, :e3)
      iex> WolframCausalGraph.sink_events(cg) |> Enum.sort()
      [:e2, :e3]
  """
  @spec sink_events(t()) :: [event_id()]
  def sink_events(%__MODULE__{} = cg) do
    cg.events
    |> Enum.filter(fn event_id -> out_degree(cg, event_id) == 0 end)
  end

  @doc """
  Performs a topological sort of the events in causal order.
  Returns a list of events in an order that respects all causal dependencies.
  Returns nil if the graph contains cycles.

  ## Examples

      iex> cg = WolframCausalGraph.new()
      iex> cg = cg
      ...>   |> WolframCausalGraph.add_event(:e1)
      ...>   |> WolframCausalGraph.add_event(:e2)
      ...>   |> WolframCausalGraph.add_event(:e3)
      ...>   |> WolframCausalGraph.add_dependency(:e1, :e2)
      ...>   |> WolframCausalGraph.add_dependency(:e2, :e3)
      iex> WolframCausalGraph.topological_sort(cg)
      [:e1, :e2, :e3]
  """
  @spec topological_sort(t()) :: [event_id()] | nil
  def topological_sort(%__MODULE__{} = cg) do
    # Kahn's algorithm
    in_degrees = Map.new(cg.events, fn event -> {event, in_degree(cg, event)} end)
    queue = Enum.filter(cg.events, fn event -> Map.get(in_degrees, event) == 0 end)

    do_topological_sort(cg, queue, in_degrees, [])
  end

  defp do_topological_sort(_cg, [], in_degrees, result) do
    if Enum.all?(in_degrees, fn {_event, degree} -> degree == 0 end) do
      Enum.reverse(result)
    else
      # Graph has cycles
      nil
    end
  end

  defp do_topological_sort(cg, [current | rest], in_degrees, result) do
    successors = immediate_successors(cg, current)

    {new_queue, new_in_degrees} =
      Enum.reduce(successors, {rest, in_degrees}, fn succ, {queue_acc, degrees_acc} ->
        new_degree = Map.get(degrees_acc, succ) - 1
        new_degrees = Map.put(degrees_acc, succ, new_degree)

        if new_degree == 0 do
          {[succ | queue_acc], new_degrees}
        else
          {queue_acc, new_degrees}
        end
      end)

    do_topological_sort(cg, new_queue, new_in_degrees, [current | result])
  end

  @doc """
  Checks if the causal graph is acyclic (has no cycles).

  ## Examples

      iex> cg = WolframCausalGraph.new()
      iex> cg = cg
      ...>   |> WolframCausalGraph.add_event(:e1)
      ...>   |> WolframCausalGraph.add_event(:e2)
      ...>   |> WolframCausalGraph.add_dependency(:e1, :e2)
      iex> WolframCausalGraph.acyclic?(cg)
      true
  """
  @spec acyclic?(t()) :: boolean()
  def acyclic?(%__MODULE__{} = cg) do
    topological_sort(cg) != nil
  end

  @doc """
  Returns metadata associated with an event.

  ## Examples

      iex> cg = WolframCausalGraph.new()
      iex> cg = WolframCausalGraph.add_event(cg, :e1, %{rule: :rule_a, step: 5})
      iex> WolframCausalGraph.event_metadata(cg, :e1)
      %{rule: :rule_a, step: 5}
  """
  @spec event_metadata(t(), event_id()) :: event_metadata() | nil
  def event_metadata(%__MODULE__{} = cg, event_id) do
    Map.get(cg.event_data, event_id)
  end

  @doc """
  Updates metadata for an event.

  ## Examples

      iex> cg = WolframCausalGraph.new()
      iex> cg = WolframCausalGraph.add_event(cg, :e1, %{rule: :rule_a})
      iex> cg = WolframCausalGraph.update_event_metadata(cg, :e1, %{rule: :rule_b})
      iex> WolframCausalGraph.event_metadata(cg, :e1)
      %{rule: :rule_b}
  """
  @spec update_event_metadata(t(), event_id(), event_metadata()) :: t()
  def update_event_metadata(%__MODULE__{} = cg, event_id, metadata) do
    if has_event?(cg, event_id) do
      %{cg | event_data: Map.put(cg.event_data, event_id, metadata)}
    else
      raise ArgumentError, "Event does not exist in the graph"
    end
  end

  ## Statistics

  @doc """
  Returns comprehensive statistics about the causal graph.

  ## Examples

      iex> cg = WolframCausalGraph.new()
      iex> cg = cg
      ...>   |> WolframCausalGraph.add_event(:e1)
      ...>   |> WolframCausalGraph.add_event(:e2)
      ...>   |> WolframCausalGraph.add_dependency(:e1, :e2)
      iex> stats = WolframCausalGraph.stats(cg)
      iex> stats.event_count
      2
      iex> stats.dependency_count
      1
  """
  @spec stats(t()) :: map()
  def stats(%__MODULE__{} = cg) do
    sources = source_events(cg)
    sinks = sink_events(cg)

    max_depth =
      if Enum.empty?(cg.events) do
        0
      else
        cg.events
        |> Enum.map(&causal_depth(cg, &1))
        |> Enum.max()
      end

    avg_in_degree =
      if event_count(cg) > 0 do
        cg.events
        |> Enum.map(&in_degree(cg, &1))
        |> Enum.sum()
        |> Kernel./(event_count(cg))
      else
        0.0
      end

    avg_out_degree =
      if event_count(cg) > 0 do
        cg.events
        |> Enum.map(&out_degree(cg, &1))
        |> Enum.sum()
        |> Kernel./(event_count(cg))
      else
        0.0
      end

    %{
      event_count: event_count(cg),
      dependency_count: dependency_count(cg),
      source_count: length(sources),
      sink_count: length(sinks),
      max_causal_depth: max_depth,
      average_in_degree: avg_in_degree,
      average_out_degree: avg_out_degree,
      is_acyclic: acyclic?(cg)
    }
  end

  @doc """
    Returns the causal cone of an event - all events causally connected to it.
    This includes both ancestors and descendants.

    ## Examples

        iex> cg= WolframCausalGraph.new()
  iex> cg = cg
  ...>   |> WolframCausalGraph.add_event(:e1)
  ...>   |> WolframCausalGraph.add_event(:e2)
  ...>   |> WolframCausalGraph.add_event(:e3)
  ...>   |> WolframCausalGraph.add_dependency(:e1, :e2)
  ...>   |> WolframCausalGraph.add_dependency(:e2, :e3)
  iex> WolframCausalGraph.causal_cone(cg, :e2) |> Enum.sort()
  [:e1, :e3]
  """
  @spec causal_cone(t(), event_id()) :: [event_id()]
  def causal_cone(%__MODULE__{} = cg, event_id) do
    (ancestors(cg, event_id) ++ descendants(cg, event_id))
    |> Enum.uniq()
  end

  @doc """
  Returns events at a specific causal depth level.

  ## Examples

  iex> cg = WolframCausalGraph.new()
    iex> cg = cg
    ...>   |> WolframCausalGraph.add_event(:e1)
    ...>   |> WolframCausalGraph.add_event(:e2)
    ...>   |> WolframCausalGraph.add_event(:e3)
    ...>   |> WolframCausalGraph.add_dependency(:e1, :e2)
    ...>   |> WolframCausalGraph.add_dependency(:e2, :e3)
    iex> WolframCausalGraph.events_at_depth(cg, 1)
    [:e2]
  """
  @spec events_at_depth(t(), non_neg_integer()) :: [event_id()]
  def events_at_depth(%__MODULE__{} = cg, depth) do
    cg.events
    |> Enum.filter(fn event -> causal_depth(cg, event) == depth end)
  end

  @doc """
  Returns the width (number of events) at each causal depth level.

  ## Examples

  iex> cg = WolframCausalGraph.new()
  iex> cg = cg
  ...>   |> WolframCausalGraph.add_event(:e1)
  ...>   |> WolframCausalGraph.add_event(:e2)
  ...>   |> WolframCausalGraph.add_event(:e3)
  ...>   |> WolframCausalGraph.add_dependency(:e1, :e2)
  ...>   |> WolframCausalGraph.add_dependency(:e1, :e3)
  iex> WolframCausalGraph.causal_width(cg)
  %{0 => 1, 1 => 2}
  """
  @spec causal_width(t()) :: %{non_neg_integer() => non_neg_integer()}
  def causal_width(%__MODULE__{} = cg) do
    cg.events
    |> Enum.group_by(&causal_depth(cg, &1))
    |> Map.new(fn {depth, events} -> {depth, length(events)} end)
  end

  Conversion

  @doc """
  Converts the causal graph to a simple adjacency list representation.

  ## Examples

  iex> cg = WolframCausalGraph.new()
  iex> cg = cg
  ...>   |> WolframCausalGraph.add_event(:e1)
  ...>   |> WolframCausalGraph.add_event(:e2)
  ...>   |> WolframCausalGraph.add_dependency(:e1, :e2)
  iex> WolframCausalGraph.to_adjacency_list(cg)
  %{e1: [:e2], e2: []}
  """
  @spec to_adjacency_list(t()) :: %{event_id() => [event_id()]}
  def to_adjacency_list(%__MODULE__{} = cg) do
    Map.new(cg.events, fn event ->
      {event, immediate_successors(cg, event)}
    end)
  end

  @doc """
  Converts the causal graph to DOT format for visualization.

  ## Examples

  iex> cg = WolframCausalGraph.new()
  iex> cg = cg
  ...>   |> WolframCausalGraph.add_event(:e1)
  ...>   |> WolframCausalGraph.add_event(:e2)
  ...>   |> WolframCausalGraph.add_dependency(:e1, :e2)
  iex> dot = WolframCausalGraph.to_dot(cg)
  iex> String.contains?(dot, "e1 -> e2")
  true
  """
  @spec to_dot(t(), keyword()) :: String.t()
  def to_dot(%__MODULE__{} = cg, opts \\ []) do
    name = Keyword.get(opts, :name, "causal_graph")

    nodes =
      cg.events
      |> Enum.map(fn event ->
        metadata = event_metadata(cg, event)

        label =
          if metadata && Map.has_key?(metadata, :rule) do
            "#{event}\\n#{Map.get(metadata, :rule)}"
          else
            "#{event}"
          end

        "  #{event} [label=\"#{label}\"];"
      end)
      |> Enum.join("\n")

    edges =
      cg.dependencies
      |> Enum.flat_map(fn {to, froms} ->
        Enum.map(froms, fn from -> "  #{from} -> #{to};" end)
      end)
      |> Enum.join("\n")

    """
    digraph #{name} {
      rankdir=TB;
    #{nodes}
    #{edges}
    }
    """
  end

  @spec to_svg(t(), keyword()) :: String.t()
  def to_svg(%__MODULE__{} = cg, opts \\ []) do
    defaults = %{node_radius: 20, x_gap: 100, y_gap: 100, margin: 50}
    opts = Map.merge(defaults, Enum.into(opts, %{}))

    # Convert dependency map (to => MapSet.froms) into a list of {from, to} tuples
    edges =
      cg.dependencies
      |> Enum.flat_map(fn {to, froms} ->
        froms |> MapSet.to_list() |> Enum.map(fn from -> {from, to} end)
      end)

    layout = layout(cg.events, edges, opts)
    render_svg(layout, edges, opts)
  end

  # Layout (layered DAG) — expects edges as [{from, to}]
  defp layout(nodes, edges, opts) do
    incoming =
      Enum.reduce(edges, %{}, fn {_, b}, acc ->
        Map.update(acc, b, 1, &(&1 + 1))
      end)

    roots = nodes |> Enum.filter(&(Map.get(incoming, &1, 0) == 0)) |> Enum.to_list()
    roots = if roots == [], do: Enum.to_list(nodes), else: roots

    layers = build_layers(roots, edges, %{}, 0, MapSet.new())

    positions =
      layers
      |> Enum.flat_map(fn {depth, nodes_at_depth} ->
        nodes_at_depth
        |> Enum.with_index()
        |> Enum.map(fn {node, i} ->
          {node,
           %{
             x: opts.margin + i * opts.x_gap,
             y: opts.margin + depth * opts.y_gap
           }}
        end)
      end)
      |> Map.new()

    positions
  end

  # Avoid revisiting nodes in cycles
  defp build_layers([], _edges, acc, _depth, _visited), do: acc

  defp build_layers(nodes, edges, acc, depth, visited) do
    nodes_unique = Enum.reject(nodes, &MapSet.member?(visited, &1))
    acc = Map.update(acc, depth, nodes_unique, &(&1 ++ nodes_unique))
    visited = Enum.reduce(nodes_unique, visited, &MapSet.put(&2, &1))

    next =
      edges
      |> Enum.filter(fn {a, _b} -> a in nodes_unique end)
      |> Enum.map(fn {_a, b} -> b end)
      |> Enum.uniq()

    build_layers(next, edges, acc, depth + 1, visited)
  end

  defp render_svg(positions, edges, opts) do
    {width, height} = svg_size(positions, opts)

    """
    <svg xmlns="http://www.w3.org/2000/svg"
         width="#{width}"
         height="#{height}"
         viewBox="0 0 #{width} #{height}">
      <defs>
        <marker id="arrow"
                markerWidth="10"
                markerHeight="10"
                refX="10"
                refY="3"
                orient="auto"
                markerUnits="strokeWidth">
          <path d="M0,0 L0,6 L9,3 z" fill="#555"/>
        </marker>
      </defs>

      #{render_edges(edges, positions, opts)}
      #{render_nodes(positions, opts)}
    </svg>
    """
  end

  defp svg_size(positions, opts) do
    xs = Enum.map(positions, fn {_k, v} -> v.x end)
    ys = Enum.map(positions, fn {_k, v} -> v.y end)

    if xs == [] or ys == [] do
      {opts.margin * 2, opts.margin * 2}
    else
      {Enum.max(xs) + opts.margin, Enum.max(ys) + opts.margin}
    end
  end

  defp render_edges(edges, pos, _opts) do
    edges
    |> Enum.filter(fn {a, b} -> Map.has_key?(pos, a) and Map.has_key?(pos, b) end)
    |> Enum.map_join("\n", fn {a, b} ->
      %{x: x1, y: y1} = pos[a]
      %{x: x2, y: y2} = pos[b]

      """
      <line x1="#{x1}" y1="#{y1}"
            x2="#{x2}" y2="#{y2}"
            stroke="#555"
            stroke-width="2"
            marker-end="url(#arrow)" />
      """
    end)
  end

  defp render_nodes(positions, opts) do
    Enum.map_join(positions, "\n", fn {id, %{x: x, y: y}} ->
      """
      <g>
        <circle cx="#{x}" cy="#{y}" r="#{opts.node_radius}"
                fill="#1f77b4" stroke="white" stroke-width="2"/>
        <text x="#{x}" y="#{y + 4}"
              text-anchor="middle"
              font-size="12"
              fill="white">#{id}</text>
      </g>
      """
    end)
  end
end
