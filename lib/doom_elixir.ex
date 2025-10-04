defmodule DoomElixir do
  @moduledoc """
  Documentation for `DoomElixir`.
  """

  @doc """
  Hello world.

  ## Examples

      iex> DoomElixir.hello()
      :world

  """
  alias DoomElixir.{Player, Renderer}

  def start_game do
    IO.puts("🎮 Démarrage du moteur de raycasting...")
    player = Player.new(3.5, 3.5, 0.0)
    frame = Renderer.render_frame(player)
    IO.puts("\n" <> frame)
    :ok
  end

  def game_loop do
    player = Player.new(3.5, 3.5, 0.0)
    render_and_wait(player)
  end

  defp render_and_wait(player) do
    IO.write("\e[2J\e[H")
    frame = Renderer.render_frame(player)
    IO.puts(frame)

    IO.puts("\n[w/a/s/d] pour bouger, [q] pour quitter")

    case IO.gets("") |> String.trim() do
      "q" -> IO.puts("Au revoir !")
      "w" -> move_player(player, :forward) |> render_and_wait()
      "s" -> move_player(player, :backward) |> render_and_wait()
      "a" -> move_player(player, :turn_left) |> render_and_wait()
      "d" -> move_player(player, :turn_right) |> render_and_wait()
      _ -> render_and_wait(player)
    end
  end

  defp move_player(player, :forward) do
    new_x = player.x + :math.cos(player.angle) * 0.3
    new_y = player.y + :math.sin(player.angle) * 0.3
    %{player | x: new_x, y: new_y}
  end

  defp move_player(player, :backward) do
    new_x = player.x - :math.cos(player.angle) * 0.3
    new_y = player.y - :math.sin(player.angle) * 0.3
    %{player | x: new_x, y: new_y}
  end

  defp move_player(player, :turn_left) do
    %{player | angle: player.angle - 0.2}
  end

  defp move_player(player, :turn_right) do
    %{player | angle: player.angle + 0.2}
  end
end
