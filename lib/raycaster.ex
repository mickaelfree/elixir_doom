defmodule DoomElixir.Raycaster do
  @moduledoc """
  Documentation for `DoomElixir.Raycaster`.
  """
  alias DoomElixir.{Player, WorldMap}

  @screen_width 500
  @screen_height 500

  def cast_rays(player) do
    # On va lancer des rayons pour chaque colonne de l'écran
    for x <- 0..(@screen_width - 1) do
      cast_single_ray(player, x)
    end
  end

  defp cast_single_ray(player, screen_x) do
    # Calcul de l'angle du rayon
    # -1 à 1
    camera_x = 2 * screen_x / @screen_width - 1
    ray_angle = player.angle + :math.atan(camera_x * :math.tan(player.fov / 2))

    # Direction du rayon
    ray_dir_x = :math.cos(ray_angle)
    ray_dir_y = :math.sin(ray_angle)

    # Lancer le rayon et trouver le mur
    distance = trace_ray(player.x, player.y, ray_dir_x, ray_dir_y)

    %{
      screen_x: screen_x,
      distance: distance,
      angle: ray_angle
    }
  end

  defp trace_ray(start_x, start_y, dir_x, dir_y) do
    trace_ray_step(start_x, start_y, dir_x, dir_y, 0.0, 0.1)
  end

  defp trace_ray_step(x, y, dir_x, dir_y, distance, step) do
    map_x = trunc(x)
    map_y = trunc(y)

    cond do
      distance >= 20.0 ->
        distance

      WorldMap.is_wall?(map_x, map_y) ->
        distance

      true ->
        new_x = x + dir_x * step
        new_y = y + dir_y * step
        trace_ray_step(new_x, new_y, dir_x, dir_y, distance + step, step)
    end
  end
end
