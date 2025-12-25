defmodule Hypergraph.NetworkGraph do
  @moduledoc """
  Utilities to render a `Hypergraph` as a network graph using `VegaLite`.

  The visualization places vertices on a circular layout and draws lines
  between vertices that share a hyperedge. Node size and color reflect
  vertex degree (number of incident hyperedges).
  """
  alias Hypergraph

  @doc """
  Render the hypergraph as a `VegaLite` visualization.

  Returns a `VegaLite` specification representing the network graph.
  Vertices are placed on a circular layout; edges are rendered as lines
  and nodes as circles sized & colored by degree.
  """
  @spec visualize(Hypergraph.t()) :: VegaLite.t()
  def visualize(hg) do
    layout =
      hg.vertices
      |> MapSet.to_list()
      |> Enum.sort()
      |> create_circular_layout(200)

    VegaLite.new(width: 800, height: 800)
    |> VegaLite.layers([
      VegaLite.new()
      |> VegaLite.data_from_values(edge_data(hg, layout))
      |> VegaLite.mark(:rule, color: "#999", opacity: 0.3, stroke_width: 1)
      |> VegaLite.encode_field(:x, "x", type: :quantitative, axis: nil)
      |> VegaLite.encode_field(:y, "y", type: :quantitative, axis: nil)
      |> VegaLite.encode_field(:x2, "x2")
      |> VegaLite.encode_field(:y2, "y2"),

      VegaLite.new()
      |> VegaLite.data_from_values(node_data(hg, layout))
      |> VegaLite.mark(:circle, opacity: 0.9, stroke: "#fff", stroke_width: 2)
      |> VegaLite.encode_field(:x, "x", type: :quantitative, axis: nil)
      |> VegaLite.encode_field(:y, "y", type: :quantitative, axis: nil)
      |> VegaLite.encode_field(:size, "size", type: :quantitative, legend: nil)
      |> VegaLite.encode_field(:color, "degree", type: :quantitative, scale: [scheme: "viridis"])
      |> VegaLite.encode_field(:tooltip, "id", type: :nominal)
      |> VegaLite.encode(:tooltip, [
        [field: "id", type: :nominal, title: "Vertex"],
        [field: "degree", type: :quantitative, title: "Degree"]
      ]),
    ])
  end

  defp edge_data(hg, layout) do
    hg.hyperedges
    |> MapSet.to_list()
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {edge, edge_id} ->
      vertices = MapSet.to_list(edge) |> Enum.sort()
      # Create all pairwise connections within each hyperedge
      for v1 <- vertices, v2 <- vertices, v1 < v2 do
        {x1, y1} = Map.get(layout, v1)
        {x2, y2} = Map.get(layout, v2)
        %{
          "x" => x1,
          "y" => y1,
          "x2" => x2,
          "y2" => y2,
          "edge_id" => edge_id,
          "size" => MapSet.size(edge)
        }
      end
    end)
  end

  defp node_data(hg, layout) do
    hg.vertices
    |> MapSet.to_list()
    |> Enum.map(fn v ->
      d = Hypergraph.degree(hg, v)
      {x, y} = Map.get(layout, v)

      %{
        "id" => v,
        "x" => x,
        "y" => y,
        "degree" => d,
        "size" => 100 + d * 20
      }
    end)
  end

  defp create_circular_layout([], _radius), do: %{}

  defp create_circular_layout(vertices, radius) do
    n = length(vertices)

    vertices
    |> Enum.with_index()
    |> Enum.map(fn {v, i} ->
      angle = 2 * :math.pi() * i / n
      x = radius * :math.cos(angle)
      y = radius * :math.sin(angle)
      {v, x, y}
    end)
    |> Map.new(fn {v, x, y} -> {v, {x, y}} end)
  end
end
