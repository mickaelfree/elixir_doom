defmodule DoomElixir.Scene.Game do
  use Scenic.Scene
  alias Scenic.Graph
  alias DoomElixir.{Player, Raycaster, WorldMap}
  import Scenic.Primitives
  require Logger

  @width 800
  @height 600
  @num_rays 400
  @move_speed 0.1
  @rotation_speed 0.1

  def init(scene, _param, _opts) do
    player = Player.new(3.5, 3.5, 0.0)

    graph =
      Graph.build()
      |> render_3d_view(player)

    scene =
      scene
      |> assign(player: player)
      |> push_graph(graph)

    # Request keyboard input
    Scenic.ViewPort.Input.request(scene.viewport, [:key])

    {:ok, scene}
  end

  # Gestion des événements clavier - Format: {:key, {key_atom, 1=press/0=release, modifiers}}
  # W/A/S/D
  def handle_input({:key, {:key_w, 1, _}}, _id, state) do
    {:noreply, move_player(state, :forward)}
  end

  def handle_input({:key, {:key_s, 1, _}}, _id, state) do
    {:noreply, move_player(state, :backward)}
  end

  def handle_input({:key, {:key_a, 1, _}}, _id, state) do
    {:noreply, move_player(state, :turn_left)}
  end

  def handle_input({:key, {:key_d, 1, _}}, _id, state) do
    {:noreply, move_player(state, :turn_right)}
  end

  # Touches fléchées
  def handle_input({:key, {:key_up, 1, _}}, _id, state) do
    {:noreply, move_player(state, :forward)}
  end

  def handle_input({:key, {:key_down, 1, _}}, _id, state) do
    {:noreply, move_player(state, :backward)}
  end

  def handle_input({:key, {:key_left, 1, _}}, _id, state) do
    {:noreply, move_player(state, :turn_left)}
  end

  def handle_input({:key, {:key_right, 1, _}}, _id, state) do
    {:noreply, move_player(state, :turn_right)}
  end

  # Logger pour debug - afficher tous les événements non gérés
  def handle_input(input, _id, state) do
    Logger.debug("Unhandled input: #{inspect(input)}")
    {:noreply, state}
  end

  defp move_player(state, :forward) do
    player = state.assigns.player
    new_x = player.x + :math.cos(player.angle) * @move_speed
    new_y = player.y + :math.sin(player.angle) * @move_speed

    if WorldMap.is_wall?(trunc(new_x), trunc(new_y)) do
      state
    else
      new_player = %{player | x: new_x, y: new_y}
      update_scene(state, new_player)
    end
  end

  defp move_player(state, :backward) do
    player = state.assigns.player
    new_x = player.x - :math.cos(player.angle) * @move_speed
    new_y = player.y - :math.sin(player.angle) * @move_speed

    if WorldMap.is_wall?(trunc(new_x), trunc(new_y)) do
      state
    else
      new_player = %{player | x: new_x, y: new_y}
      update_scene(state, new_player)
    end
  end

  defp move_player(state, :turn_left) do
    player = state.assigns.player
    new_player = %{player | angle: player.angle - @rotation_speed}
    update_scene(state, new_player)
  end

  defp move_player(state, :turn_right) do
    player = state.assigns.player
    new_player = %{player | angle: player.angle + @rotation_speed}
    update_scene(state, new_player)
  end

  defp update_scene(state, new_player) do
    graph =
      Graph.build()
      |> render_3d_view(new_player)

    state
    |> assign(player: new_player)
    |> push_graph(graph)
  end

  defp render_3d_view(graph, player) do
    # Optimisé : utiliser un nombre fixe de rayons au lieu de 500
    rays = cast_optimized_rays(player)

    # Fond (ciel et sol)
    graph =
      graph
      |> rect({@width, @height / 2}, fill: {:color, {135, 206, 235}}, translate: {0, 0})
      |> rect({@width, @height / 2}, fill: {:color, {101, 67, 33}}, translate: {0, @height / 2})

    # Dessiner les murs
    rays
    |> Enum.with_index()
    |> Enum.reduce(graph, fn {ray, x}, acc ->
      wall_height = calculate_wall_height(ray.distance)
      wall_start = (@height - wall_height) / 2
      wall_x = x * (@width / @num_rays)

      # Calculer la couleur en fonction de la distance (effet de profondeur)
      brightness = max(50, 255 - trunc(ray.distance * 20))
      color = {brightness, brightness, brightness}

      # Dessiner une ligne verticale épaisse pour chaque rayon
      acc
      |> rect(
        {@width / @num_rays + 1, wall_height},
        fill: {:color, color},
        translate: {wall_x, wall_start}
      )
    end)
  end

  defp cast_optimized_rays(player) do
    for i <- 0..(@num_rays - 1) do
      screen_x = i * (500 / @num_rays)
      Raycaster.cast_single_ray_public(player, screen_x)
    end
  end

  defp calculate_wall_height(distance) do
    wall_height = @height / (distance + 0.1)
    min(wall_height, @height)
  end
end
