defmodule DoomElixir.Scene.Game do
  use Scenic.Scene
  alias Scenic.Graph
  alias DoomElixir.{Player, Raycaster}

  @width 800
  @height 600

  def init(scene, _param, _opts) do
    player = Player.new(3.5, 3.5, 0.0)

    graph =
      Graph.build()
      |> render_3d_view(player)

    scene =
      scene
      |> assign(player: player, graph: graph)
      |> push_graph(graph)

    {:ok, scene}
  end

  defp render_3d_view(graph, player) do
    rays = Raycaster.cast_rays(player)

    rays
    |> Enum.with_index()
    |> Enum.reduce(graph, fn {ray, x}, acc ->
      wall_height = calculate_wall_height(ray.distance)
      wall_start = (@height - wall_height) / 2

      # Dessiner une ligne verticale pour chaque rayon
      acc
      |> Scenic.Primitives.line(
        {{x * (@width / length(rays)), wall_start},
         {x * (@width / length(rays)), wall_start + wall_height}},
        stroke: {2, :white}
      )
    end)
  end

  defp calculate_wall_height(distance) do
    wall_height = @height / (distance + 0.1)
    min(wall_height, @height)
  end
end
