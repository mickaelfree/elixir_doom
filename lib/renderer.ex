defmodule DoomElixir.Renderer do
  @moduledoc """
  Documentation for `DoomElixir.Renderer`.
  """
  alias DoomElixir.Raycaster

  @screen_height 20

  def render_frame(player) do
    # Lancer tous les rayons
    rays = Raycaster.cast_rays(player)

    # Convertir en hauteurs de murs
    wall_heights = Enum.map(rays, &calculate_wall_height/1)

    # Dessiner ligne par ligne
    for y <- 0..(@screen_height - 1) do
      render_line(wall_heights, y)
    end
    |> Enum.join("\n")
  end

  defp calculate_wall_height(%{distance: distance}) do
    # Plus le mur est proche, plus il est haut
    wall_height = trunc(@screen_height / (distance + 0.1))
    min(wall_height, @screen_height)
  end

  defp render_line(wall_heights, y) do
    Enum.map(wall_heights, fn height ->
      wall_start = div(@screen_height - height, 2)
      wall_end = wall_start + height

      cond do
        y < wall_start -> " "
        y >= wall_start and y < wall_end -> "#"
        true -> "."
      end
    end)
    |> Enum.join("")
  end
end
