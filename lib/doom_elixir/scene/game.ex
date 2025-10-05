defmodule DoomElixir.Scene.Game do
  use Scenic.Scene
  alias Scenic.Graph
  alias DoomElixir.{Player, Raycaster, WorldMap}
  import Scenic.Primitives
  require Logger

  @width 800
  @height 600
  @num_rays 400
  @move_speed 0.2
  @rotation_speed 0.12
  @minimap_size 150
  @minimap_scale 15
  @frame_rate 60

  def init(scene, _param, _opts) do
    player = Player.new(3.5, 3.5, 0.0)

    graph =
      Graph.build()
      |> render_3d_view(player, {0.5, 0.5})

    scene =
      scene
      |> assign(
        player: player,
        keys_pressed: MapSet.new(),
        last_update: System.monotonic_time(:millisecond),
        head_position: {0.5, 0.5}  # Position de la tête (centre par défaut)
      )
      |> push_graph(graph)

    # Request keyboard input
    Scenic.ViewPort.Input.request(scene.viewport, [:key])

    # Démarrer la boucle de mise à jour
    Process.send_after(self(), :update, trunc(1000 / @frame_rate))

    {:ok, scene}
  end

  # Boucle de mise à jour continue
  def handle_info(:update, state) do
    current_time = System.monotonic_time(:millisecond)
    delta_time = (current_time - state.assigns.last_update) / 1000.0

    # Récupérer la position de la tête depuis l'eye tracking
    head_position = DoomElixir.EyeTracking.get_gaze_position()

    # Mettre à jour en fonction des touches pressées
    new_player = update_player_from_keys(state.assigns.player, state.assigns.keys_pressed, delta_time)

    # Re-render si le joueur a bougé OU si la tête a bougé
    state =
      if new_player != state.assigns.player || head_position != state.assigns.head_position do
        graph =
          Graph.build()
          |> render_3d_view(new_player, head_position)

        state
        |> assign(player: new_player, last_update: current_time, head_position: head_position)
        |> push_graph(graph)
      else
        assign(state, last_update: current_time)
      end

    # Programmer la prochaine mise à jour
    Process.send_after(self(), :update, trunc(1000 / @frame_rate))

    {:noreply, state}
  end

  # Gestion des événements clavier - on maintient un état des touches pressées
  # Press (1 ou 2)
  def handle_input({:key, {key, action, _}}, _id, state) when action > 0 and key in [:key_w, :key_s, :key_a, :key_d, :key_q, :key_e, :key_up, :key_down, :key_left, :key_right] do
    keys_pressed = MapSet.put(state.assigns.keys_pressed, key)
    {:noreply, assign(state, keys_pressed: keys_pressed)}
  end

  # Release (0)
  def handle_input({:key, {key, 0, _}}, _id, state) when key in [:key_w, :key_s, :key_a, :key_d, :key_q, :key_e, :key_up, :key_down, :key_left, :key_right] do
    keys_pressed = MapSet.delete(state.assigns.keys_pressed, key)
    {:noreply, assign(state, keys_pressed: keys_pressed)}
  end

  # Ignorer les autres événements
  def handle_input(_input, _id, state) do
    {:noreply, state}
  end

  # Mise à jour du joueur basée sur les touches pressées
  defp update_player_from_keys(player, keys_pressed, _delta_time) do
    player
    |> apply_key_movement(keys_pressed)
  end

  defp apply_key_movement(player, keys_pressed) do
    player
    |> move_if_key_pressed(keys_pressed, [:key_w, :key_up], :forward)
    |> move_if_key_pressed(keys_pressed, [:key_s, :key_down], :backward)
    |> move_if_key_pressed(keys_pressed, [:key_a, :key_left], :turn_left)
    |> move_if_key_pressed(keys_pressed, [:key_d, :key_right], :turn_right)
    |> move_if_key_pressed(keys_pressed, [:key_q], :strafe_left)
    |> move_if_key_pressed(keys_pressed, [:key_e], :strafe_right)
  end

  defp move_if_key_pressed(player, keys_pressed, keys, action) do
    if Enum.any?(keys, &MapSet.member?(keys_pressed, &1)) do
      apply_movement(player, action)
    else
      player
    end
  end

  defp apply_movement(player, :forward) do
    new_x = player.x + :math.cos(player.angle) * @move_speed
    new_y = player.y + :math.sin(player.angle) * @move_speed

    if WorldMap.is_wall?(trunc(new_x), trunc(new_y)) do
      player
    else
      %{player | x: new_x, y: new_y}
    end
  end

  defp apply_movement(player, :backward) do
    new_x = player.x - :math.cos(player.angle) * @move_speed
    new_y = player.y - :math.sin(player.angle) * @move_speed

    if WorldMap.is_wall?(trunc(new_x), trunc(new_y)) do
      player
    else
      %{player | x: new_x, y: new_y}
    end
  end

  defp apply_movement(player, :turn_left) do
    %{player | angle: player.angle - @rotation_speed}
  end

  defp apply_movement(player, :turn_right) do
    %{player | angle: player.angle + @rotation_speed}
  end

  defp apply_movement(player, :strafe_left) do
    strafe_angle = player.angle - :math.pi() / 2
    new_x = player.x + :math.cos(strafe_angle) * @move_speed
    new_y = player.y + :math.sin(strafe_angle) * @move_speed

    if WorldMap.is_wall?(trunc(new_x), trunc(new_y)) do
      player
    else
      %{player | x: new_x, y: new_y}
    end
  end

  defp apply_movement(player, :strafe_right) do
    strafe_angle = player.angle + :math.pi() / 2
    new_x = player.x + :math.cos(strafe_angle) * @move_speed
    new_y = player.y + :math.sin(strafe_angle) * @move_speed

    if WorldMap.is_wall?(trunc(new_x), trunc(new_y)) do
      player
    else
      %{player | x: new_x, y: new_y}
    end
  end

  defp render_3d_view(graph, player, head_position) do
    # Optimisé : utiliser un nombre fixe de rayons au lieu de 500
    rays = cast_optimized_rays(player, head_position)

    # Calculer l'offset de perspective basé sur la position de la tête
    {head_x, head_y} = head_position
    # Convertir de [0, 1] à [-1, 1] pour centrer
    perspective_x = (head_x - 0.5) * 2.0
    perspective_y = (head_y - 0.5) * 2.0

    # Fond (ciel et sol avec dégradé) - décalé selon la position de la tête
    horizon_offset = trunc(perspective_y * 100)

    graph =
      graph
      |> rect({@width, @height / 2 + horizon_offset}, fill: {:color, {100, 149, 237}}, translate: {0, 0})
      |> rect({@width, @height / 2 - horizon_offset}, fill: {:color, {85, 107, 47}}, translate: {0, @height / 2 + horizon_offset})

    # Dessiner les murs avec couleurs basées sur orientation et effet de parallaxe
    graph =
      rays
      |> Enum.with_index()
      |> Enum.reduce(graph, fn {ray, x}, acc ->
        wall_height = calculate_wall_height(ray.distance)

        # Effet de parallaxe : les murs proches bougent plus que les murs loin
        parallax_factor = 1.0 / (ray.distance + 0.5)
        horizontal_shift = perspective_x * 30 * parallax_factor
        vertical_shift = horizon_offset + (perspective_y * 20 * parallax_factor)

        wall_start = (@height - wall_height) / 2 + vertical_shift
        wall_x = x * (@width / @num_rays) + horizontal_shift

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

  defp cast_optimized_rays(player, {head_x, head_y}) do
    # Ajuster le FOV et l'angle de base selon la position de la tête
    head_offset_x = (head_x - 0.5) * 0.3  # Ajustement subtil de l'angle
    head_offset_y = (head_y - 0.5) * 0.2  # Pour futur support vertical

    for i <- 0..(@num_rays - 1) do
      screen_x = i * (500 / @num_rays)
      # Créer un joueur virtuel avec angle ajusté
      adjusted_player = %{player | angle: player.angle + head_offset_x}
      Raycaster.cast_single_ray_public(adjusted_player, screen_x)
    end
  end

  defp calculate_wall_height(distance) do
    wall_height = @height / (distance + 0.1)
    min(wall_height, @height)
  end
end
