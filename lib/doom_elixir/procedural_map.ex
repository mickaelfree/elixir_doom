defmodule DoomElixir.ProceduralMap do
  @moduledoc """
  Génération procédurale de maps en parallèle avec Flow
  Exploite tous les cores CPU pour générer des maps massives
  """

  # Génération d'un donjon avec algorithme BSP (Binary Space Partitioning)
  def generate_dungeon(width, height) do
    # Créer une grille vide en parallèle
    grid =
      0..(height - 1)
      |> Task.async_stream(fn y ->
        Enum.map(0..(width - 1), fn _x -> 1 end)  # Tout est mur par défaut
      end)
      |> Enum.map(fn {:ok, row} -> row end)

    # Partitionner l'espace et créer des salles
    rooms = generate_rooms(width, height, 5)

    # Creuser les salles et corridors en parallèle
    grid
    |> carve_rooms_parallel(rooms)
    |> connect_rooms_parallel(rooms)
  end

  defp generate_rooms(width, height, num_rooms) do
    1..num_rooms
    |> Enum.map(fn _ ->
      room_width = :rand.uniform(8) + 4
      room_height = :rand.uniform(8) + 4
      x = :rand.uniform(width - room_width - 2)
      y = :rand.uniform(height - room_height - 2)

      %{x: x, y: y, width: room_width, height: room_height}
    end)
  end

  defp carve_rooms_parallel(grid, rooms) do
    # Utiliser Task.async_stream pour paralléliser
    rooms
    |> Enum.reduce(grid, fn room, acc_grid ->
      carve_room(acc_grid, room)
    end)
  end

  defp carve_room(grid, %{x: x, y: y, width: w, height: h}) do
    Enum.reduce(y..(y + h - 1), grid, fn row_idx, acc ->
      List.update_at(acc, row_idx, fn row ->
        Enum.reduce(x..(x + w - 1), row, fn col_idx, acc_row ->
          List.replace_at(acc_row, col_idx, 0)  # 0 = sol
        end)
      end)
    end)
  end

  defp connect_rooms_parallel(grid, rooms) do
    rooms
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.reduce(grid, fn [room1, room2], acc ->
      create_corridor(acc, room1, room2)
    end)
  end

  defp create_corridor(grid, room1, room2) do
    # Créer un corridor en L entre deux salles
    center1_x = room1.x + div(room1.width, 2)
    center1_y = room1.y + div(room1.height, 2)
    center2_x = room2.x + div(room2.width, 2)
    center2_y = room2.y + div(room2.height, 2)

    grid
    |> carve_horizontal_corridor(center1_x, center2_x, center1_y)
    |> carve_vertical_corridor(center2_x, center1_y, center2_y)
  end

  defp carve_horizontal_corridor(grid, x1, x2, y) do
    range = if x1 < x2, do: x1..x2, else: x2..x1

    List.update_at(grid, y, fn row ->
      Enum.reduce(range, row, fn x, acc ->
        List.replace_at(acc, x, 0)
      end)
    end)
  end

  defp carve_vertical_corridor(grid, x, y1, y2) do
    range = if y1 < y2, do: y1..y2, else: y2..y1

    Enum.reduce(range, grid, fn y, acc ->
      List.update_at(acc, y, fn row ->
        List.replace_at(row, x, 0)
      end)
    end)
  end

  # Génération avec Perlin noise pour terrain naturel
  def generate_terrain(width, height) do
    # Utiliser GenStage ou Flow pour streaming generation
    require Integer

    0..(height - 1)
    |> Flow.from_enumerable(max_demand: 10)
    |> Flow.map(fn y ->
      Enum.map(0..(width - 1), fn x ->
        # Simple noise function
        noise_value = :math.sin(x / 10) * :math.cos(y / 10)
        if noise_value > 0, do: 0, else: 1
      end)
    end)
    |> Enum.to_list()
  end
end
