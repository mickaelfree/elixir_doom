defmodule DoomElixir.Scene.Game do
  use Scenic.Scene
  alias Scenic.Graph
  alias DoomElixir.{Player, Raycaster, WorldMap}
  import Scenic.Primitives
  require Logger

  @width 800
  @height 600
  @num_rays 400
  @move_speed 0.15
  @rotation_speed 0.08
  @minimap_size 150
  @minimap_scale 15

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

  # Gestion des événements clavier - Format: {:key, {key_atom, action, modifiers}}
  # action: 1 = press, 2 = repeat, 0 = release
  # W/A/S/D - on ignore les release (0)
  def handle_input({:key, {:key_w, action, _}}, _id, state) when action > 0 do
    {:noreply, move_player(state, :forward)}
  end

  def handle_input({:key, {:key_s, action, _}}, _id, state) when action > 0 do
    {:noreply, move_player(state, :backward)}
  end

  def handle_input({:key, {:key_a, action, _}}, _id, state) when action > 0 do
    {:noreply, move_player(state, :turn_left)}
  end

  def handle_input({:key, {:key_d, action, _}}, _id, state) when action > 0 do
    {:noreply, move_player(state, :turn_right)}
  end

  # Touches fléchées
  def handle_input({:key, {:key_up, action, _}}, _id, state) when action > 0 do
    {:noreply, move_player(state, :forward)}
  end

  def handle_input({:key, {:key_down, action, _}}, _id, state) when action > 0 do
    {:noreply, move_player(state, :backward)}
  end

  def handle_input({:key, {:key_left, action, _}}, _id, state) when action > 0 do
    {:noreply, move_player(state, :turn_left)}
  end

  def handle_input({:key, {:key_right, action, _}}, _id, state) when action > 0 do
    {:noreply, move_player(state, :turn_right)}
  end

  # Strafing (Q/E)
  def handle_input({:key, {:key_q, action, _}}, _id, state) when action > 0 do
    {:noreply, move_player(state, :strafe_left)}
  end

  def handle_input({:key, {:key_e, action, _}}, _id, state) when action > 0 do
    {:noreply, move_player(state, :strafe_right)}
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

  defp move_player(state, :strafe_left) do
    player = state.assigns.player
    # Strafe perpendiculaire à la direction
    strafe_angle = player.angle - :math.pi() / 2
    new_x = player.x + :math.cos(strafe_angle) * @move_speed
    new_y = player.y + :math.sin(strafe_angle) * @move_speed

    if WorldMap.is_wall?(trunc(new_x), trunc(new_y)) do
      state
    else
      new_player = %{player | x: new_x, y: new_y}
      update_scene(state, new_player)
    end
  end

  defp move_player(state, :strafe_right) do
    player = state.assigns.player
    # Strafe perpendiculaire à la direction
    strafe_angle = player.angle + :math.pi() / 2
    new_x = player.x + :math.cos(strafe_angle) * @move_speed
    new_y = player.y + :math.sin(strafe_angle) * @move_speed

    if WorldMap.is_wall?(trunc(new_x), trunc(new_y)) do
      state
    else
      new_player = %{player | x: new_x, y: new_y}
      update_scene(state, new_player)
    end
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

    # Fond (ciel et sol avec dégradé)
    graph =
      graph
      |> rect({@width, @height / 2}, fill: {:color, {100, 149, 237}}, translate: {0, 0})
      |> rect({@width, @height / 2}, fill: {:color, {85, 107, 47}}, translate: {0, @height / 2})

    # Dessiner les murs avec couleurs basées sur orientation
    graph =
      rays
      |> Enum.with_index()
      |> Enum.reduce(graph, fn {ray, x}, acc ->
        wall_height = calculate_wall_height(ray.distance)
        wall_start = (@height - wall_height) / 2
        wall_x = x * (@width / @num_rays)

        # Couleur basée sur la distance et l'orientation du mur
        base_color = get_wall_color(ray)
        brightness_factor = max(0.3, 1.0 - ray.distance / 15)

        color =
          Enum.map(Tuple.to_list(base_color), fn c ->
            trunc(c * brightness_factor)
          end)
          |> List.to_tuple()

        # Dessiner une ligne verticale épaisse pour chaque rayon
        acc
        |> rect(
          {@width / @num_rays + 1, wall_height},
          fill: {:color, color},
          translate: {wall_x, wall_start}
        )
      end)

    # Ajouter minimap
    graph = draw_minimap(graph, player)

    # Ajouter HUD
    draw_hud(graph, player)
  end

  defp get_wall_color(ray) do
    # Déterminer l'orientation approximative du mur basée sur l'angle
    angle_deg = ray.angle * 180 / :math.pi()
    angle_normalized = rem(trunc(angle_deg + 360), 360)

    cond do
      angle_normalized >= 45 && angle_normalized < 135 -> {200, 100, 100}   # Rouge (Nord)
      angle_normalized >= 135 && angle_normalized < 225 -> {100, 100, 200}  # Bleu (Est)
      angle_normalized >= 225 && angle_normalized < 315 -> {100, 200, 100}  # Vert (Sud)
      true -> {200, 200, 100}  # Jaune (Ouest)
    end
  end

  defp draw_minimap(graph, player) do
    map = WorldMap.get_map()
    minimap_x = @width - @minimap_size - 20
    minimap_y = 20

    # Fond semi-transparent de la minimap
    graph =
      graph
      |> rect(
        {@minimap_size, @minimap_size},
        fill: {:color, {0, 0, 0, 180}},
        translate: {minimap_x, minimap_y}
      )

    # Dessiner la carte
    graph =
      map
      |> Enum.with_index()
      |> Enum.reduce(graph, fn {row, y}, acc ->
        row
        |> Enum.with_index()
        |> Enum.reduce(acc, fn {cell, x}, acc2 ->
          if cell == 1 do
            acc2
            |> rect(
              {@minimap_scale, @minimap_scale},
              fill: {:color, {150, 150, 150}},
              translate: {minimap_x + x * @minimap_scale, minimap_y + y * @minimap_scale}
            )
          else
            acc2
          end
        end)
      end)

    # Dessiner le joueur sur la minimap
    player_map_x = minimap_x + player.x * @minimap_scale - 3
    player_map_y = minimap_y + player.y * @minimap_scale - 3

    # Direction du joueur
    dir_length = 10
    dir_x = player_map_x + 3 + :math.cos(player.angle) * dir_length
    dir_y = player_map_y + 3 + :math.sin(player.angle) * dir_length

    graph
    |> circle(3, fill: {:color, {255, 255, 0}}, translate: {player_map_x + 3, player_map_y + 3})
    |> line({{player_map_x + 3, player_map_y + 3}, {dir_x, dir_y}}, stroke: {2, :yellow})
  end

  defp draw_hud(graph, player) do
    # Position et angle
    pos_text = "Pos: (#{Float.round(player.x, 1)}, #{Float.round(player.y, 1)})"
    angle_deg = player.angle * 180 / :math.pi()
    angle_text = "Angle: #{trunc(angle_deg)}°"

    # Contrôles
    controls =
      "WASD: Move | Q/E: Strafe | Arrows: Move/Turn"

    graph
    |> text(pos_text, translate: {10, 20}, fill: :white, font_size: 16)
    |> text(angle_text, translate: {10, 40}, fill: :white, font_size: 16)
    |> text(controls, translate: {10, @height - 20}, fill: :lime, font_size: 14)
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
