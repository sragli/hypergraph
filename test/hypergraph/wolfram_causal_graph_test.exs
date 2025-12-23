defmodule Hypergraph.WolframCausalGraphTest do
  use ExUnit.Case, async: true
  alias Hypergraph.WolframCausalGraph

  test "construction with new/0 and new/2" do
    cg = WolframCausalGraph.new()
    assert WolframCausalGraph.event_count(cg) == 0

    cg2 = WolframCausalGraph.new([{:e1, %{rule: :r1}}, {:e2, %{}}], [{:e1, :e2}])
    assert WolframCausalGraph.event_count(cg2) == 2
    assert WolframCausalGraph.is_causal_predecessor?(cg2, :e1, :e2)
  end

  test "add_event, has_event?, event_metadata, update_event_metadata" do
    cg = WolframCausalGraph.new()
    cg = WolframCausalGraph.add_event(cg, :a, %{rule: :alpha})
    assert WolframCausalGraph.has_event?(cg, :a)
    assert WolframCausalGraph.event_metadata(cg, :a) == %{rule: :alpha}

    cg = WolframCausalGraph.update_event_metadata(cg, :a, %{rule: :beta})
    assert WolframCausalGraph.event_metadata(cg, :a) == %{rule: :beta}

    assert_raise ArgumentError, fn ->
      WolframCausalGraph.update_event_metadata(cg, :missing, %{})
    end
  end

  test "add_dependency requires existing events and remove_dependency works" do
    cg =
      WolframCausalGraph.new()
      |> WolframCausalGraph.add_event(:a)
      |> WolframCausalGraph.add_event(:b)

    assert_raise ArgumentError, fn ->
      WolframCausalGraph.add_dependency(WolframCausalGraph.new(), :x, :y)
    end

    cg = WolframCausalGraph.add_dependency(cg, :a, :b)
    assert WolframCausalGraph.is_causal_predecessor?(cg, :a, :b)
    cg = WolframCausalGraph.remove_dependency(cg, :a, :b)
    refute WolframCausalGraph.is_causal_predecessor?(cg, :a, :b)
  end

  test "remove_event removes associated relations" do
    cg =
      WolframCausalGraph.new()
      |> WolframCausalGraph.add_event(:a)
      |> WolframCausalGraph.add_event(:b)
      |> WolframCausalGraph.add_dependency(:a, :b)

    cg = WolframCausalGraph.remove_event(cg, :a)
    refute WolframCausalGraph.has_event?(cg, :a)
    assert WolframCausalGraph.in_degree(cg, :b) == 0
  end

  test "immediate predecessors/successors, ancestors/descendants" do
    cg =
      WolframCausalGraph.new()
      |> WolframCausalGraph.add_event(:a)
      |> WolframCausalGraph.add_event(:b)
      |> WolframCausalGraph.add_event(:c)
      |> WolframCausalGraph.add_dependency(:a, :b)
      |> WolframCausalGraph.add_dependency(:b, :c)

    assert Enum.sort(WolframCausalGraph.immediate_predecessors(cg, :b)) == [:a]
    assert Enum.sort(WolframCausalGraph.immediate_successors(cg, :b)) == [:c]

    assert MapSet.new(WolframCausalGraph.ancestors(cg, :c)) == MapSet.new([:a, :b])
    assert MapSet.new(WolframCausalGraph.descendants(cg, :a)) == MapSet.new([:b, :c])
    assert WolframCausalGraph.is_causal_predecessor?(cg, :a, :c)
  end

  test "degrees, sources and sinks" do
    cg =
      WolframCausalGraph.new()
      |> WolframCausalGraph.add_event(:s)
      |> WolframCausalGraph.add_event(:m)
      |> WolframCausalGraph.add_event(:t)
      |> WolframCausalGraph.add_dependency(:s, :m)
      |> WolframCausalGraph.add_dependency(:m, :t)

    assert WolframCausalGraph.in_degree(cg, :m) == 1
    assert WolframCausalGraph.out_degree(cg, :m) == 1
    assert Enum.sort(WolframCausalGraph.source_events(cg)) == [:s]
    assert Enum.sort(WolframCausalGraph.sink_events(cg)) == [:t]
  end

  test "causal_depth, events_at_depth and causal_width" do
    cg =
      WolframCausalGraph.new()
      |> WolframCausalGraph.add_event(:a)
      |> WolframCausalGraph.add_event(:b)
      |> WolframCausalGraph.add_event(:c)
      |> WolframCausalGraph.add_event(:d)
      |> WolframCausalGraph.add_dependency(:a, :b)
      |> WolframCausalGraph.add_dependency(:a, :c)
      |> WolframCausalGraph.add_dependency(:b, :d)
      |> WolframCausalGraph.add_dependency(:c, :d)

    assert WolframCausalGraph.causal_depth(cg, :a) == 0
    assert WolframCausalGraph.causal_depth(cg, :b) == 1
    assert WolframCausalGraph.causal_depth(cg, :d) == 2

    assert WolframCausalGraph.events_at_depth(cg, 1) |> Enum.sort() == [:b, :c]
    assert WolframCausalGraph.causal_width(cg)[0] == 1
    assert WolframCausalGraph.causal_width(cg)[1] == 2
    assert WolframCausalGraph.causal_width(cg)[2] == 1
  end

  test "topological sort and cycles detection" do
    cg =
      WolframCausalGraph.new()
      |> WolframCausalGraph.add_event(:a)
      |> WolframCausalGraph.add_event(:b)
      |> WolframCausalGraph.add_event(:c)
      |> WolframCausalGraph.add_dependency(:a, :b)
      |> WolframCausalGraph.add_dependency(:b, :c)

    topo = WolframCausalGraph.topological_sort(cg)
    assert Enum.find_index(topo, &(&1 == :a)) < Enum.find_index(topo, &(&1 == :b))
    assert WolframCausalGraph.acyclic?(cg)

    cyc =
      WolframCausalGraph.new()
      |> WolframCausalGraph.add_event(:x)
      |> WolframCausalGraph.add_event(:y)
      |> WolframCausalGraph.add_dependency(:x, :y)
      |> WolframCausalGraph.add_dependency(:y, :x)

    assert WolframCausalGraph.topological_sort(cyc) == nil
    refute WolframCausalGraph.acyclic?(cyc)

    # ... existing cyc creation ...
    assert WolframCausalGraph.topological_sort(cyc) == nil
    refute WolframCausalGraph.acyclic?(cyc)

    # new: computing depth on a cyclic graph should raise
    assert_raise ArgumentError, fn ->
      WolframCausalGraph.causal_depth(cyc, :x)
    end
  end

  test "stats, dependency_count and causal_cone" do
    cg =
      WolframCausalGraph.new()
      |> WolframCausalGraph.add_event(:a)
      |> WolframCausalGraph.add_event(:b)
      |> WolframCausalGraph.add_event(:c)
      |> WolframCausalGraph.add_dependency(:a, :b)
      |> WolframCausalGraph.add_dependency(:b, :c)

    stats = WolframCausalGraph.stats(cg)
    assert stats.event_count == 3
    assert stats.dependency_count == 2
    assert stats.is_acyclic
    assert MapSet.new(WolframCausalGraph.causal_cone(cg, :b)) == MapSet.new([:a, :c])
  end

  test "to_adjacency_list and to_dot include edges and labels" do
    cg =
      WolframCausalGraph.new()
      |> WolframCausalGraph.add_event(:a, %{rule: :R})
      |> WolframCausalGraph.add_event(:b)
      |> WolframCausalGraph.add_dependency(:a, :b)

    adj = WolframCausalGraph.to_adjacency_list(cg)
    assert adj[:a] == [:b]
    assert adj[:b] == []

    dot = WolframCausalGraph.to_dot(cg)
    assert String.contains?(dot, "a -> b")
    # label from metadata
    assert String.contains?(dot, "R")
  end

  test "events_at_depth returns empty for non-existing depth" do
    cg =
      WolframCausalGraph.new()
      |> WolframCausalGraph.add_event(:a)

    assert WolframCausalGraph.events_at_depth(cg, 10) == []
  end

  test "from_hypergraph creates events and deterministic dependencies" do
    hg = Hypergraph.new() |> Hypergraph.add_hyperedge([:a, :b, :c])
    cg = WolframCausalGraph.from_hypergraph(hg)

    assert WolframCausalGraph.event_count(cg) == 3
    assert WolframCausalGraph.is_causal_predecessor?(cg, :a, :b)
    assert WolframCausalGraph.is_causal_predecessor?(cg, :a, :c)
    assert WolframCausalGraph.is_causal_predecessor?(cg, :b, :c)

    topo = WolframCausalGraph.topological_sort(cg)
    assert Enum.find_index(topo, &(&1 == :a)) < Enum.find_index(topo, &(&1 == :b))
    assert Enum.find_index(topo, &(&1 == :b)) < Enum.find_index(topo, &(&1 == :c))
  end

  test "from_hypergraph handles multiple hyperedges and transitive relations" do
    hg =
      Hypergraph.new()
      |> Hypergraph.add_hyperedge([:x, :y])
      |> Hypergraph.add_hyperedge([:y, :z])

    cg = WolframCausalGraph.from_hypergraph(hg)
    assert WolframCausalGraph.is_causal_predecessor?(cg, :x, :y)
    assert WolframCausalGraph.is_causal_predecessor?(cg, :y, :z)
    # transitive
    assert WolframCausalGraph.is_causal_predecessor?(cg, :x, :z)
  end

  test "to_svg produces an SVG for a simple DAG" do
    hg = Hypergraph.new() |> Hypergraph.add_hyperedge([:a, :b, :c])
    cg = WolframCausalGraph.from_hypergraph(hg)
    svg = WolframCausalGraph.to_svg(cg)
    assert is_binary(svg)
    assert String.starts_with?(String.trim(svg), "<svg")
    assert String.contains?(svg, "<circle")
    assert String.contains?(svg, "<line")
  end

  test "to_svg handles cycles without crashing" do
    cyc =
      WolframCausalGraph.new()
      |> WolframCausalGraph.add_event(:x)
      |> WolframCausalGraph.add_event(:y)
      |> WolframCausalGraph.add_dependency(:x, :y)
      |> WolframCausalGraph.add_dependency(:y, :x)

    svg = WolframCausalGraph.to_svg(cyc)
    assert is_binary(svg)
    assert String.starts_with?(String.trim(svg), "<svg")
  end
end
