defmodule DoomElixir.GameServer do
  use GenServer

  @moduledoc """
  Serveur de jeu central gérant tous les joueurs et entités
  Exploite la concurrence d'Elixir pour gérer des milliers de joueurs
  """

  defstruct [:players, :entities, :world_map]

  # Client API
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def add_player(player_id, position) do
    GenServer.call(__MODULE__, {:add_player, player_id, position})
  end

  def move_player(player_id, new_position) do
    GenServer.cast(__MODULE__, {:move_player, player_id, new_position})
  end

  def get_visible_players(player_id) do
    GenServer.call(__MODULE__, {:get_visible_players, player_id})
  end

  def broadcast_state do
    GenServer.cast(__MODULE__, :broadcast_state)
  end

  # Server Callbacks
  @impl true
  def init(_opts) do
    # Broadcast périodique pour tous les clients
    :timer.send_interval(16, self(), :tick)  # 60 FPS

    {:ok, %__MODULE__{
      players: %{},
      entities: [],
      world_map: DoomElixir.WorldMap.get_map()
    }}
  end

  @impl true
  def handle_call({:add_player, player_id, position}, _from, state) do
    new_players = Map.put(state.players, player_id, %{
      id: player_id,
      position: position,
      health: 100,
      last_seen: System.monotonic_time(:millisecond)
    })

    {:reply, :ok, %{state | players: new_players}}
  end

  @impl true
  def handle_call({:get_visible_players, player_id}, _from, state) do
    current_player = Map.get(state.players, player_id)

    visible_players =
      state.players
      |> Enum.reject(fn {id, _} -> id == player_id end)
      |> Enum.filter(fn {_, other_player} ->
        distance = calculate_distance(current_player.position, other_player.position)
        distance < 10  # Visible dans un rayon de 10 unités
      end)
      |> Enum.into(%{})

    {:reply, visible_players, state}
  end

  @impl true
  def handle_cast({:move_player, player_id, new_position}, state) do
    new_players =
      Map.update(state.players, player_id, nil, fn player ->
        %{player |
          position: new_position,
          last_seen: System.monotonic_time(:millisecond)
        }
      end)

    {:noreply, %{state | players: new_players}}
  end

  @impl true
  def handle_cast(:broadcast_state, state) do
    # Broadcast l'état à tous les joueurs connectés
    Phoenix.PubSub.broadcast(DoomElixir.PubSub, "game:state", {:game_state, state})
    {:noreply, state}
  end

  @impl true
  def handle_info(:tick, state) do
    # Update game logic every tick
    # Déplacer les NPCs, vérifier les collisions, etc.
    new_state = update_game_state(state)

    # Broadcast to all connected players
    Phoenix.PubSub.broadcast(DoomElixir.PubSub, "game:state", {:game_tick, new_state})

    {:noreply, new_state}
  end

  # Helpers
  defp calculate_distance({x1, y1}, {x2, y2}) do
    :math.sqrt(:math.pow(x2 - x1, 2) + :math.pow(y2 - y1, 2))
  end

  defp update_game_state(state) do
    # Update NPCs avec Tasks parallèles
    updated_entities =
      state.entities
      |> Task.async_stream(&update_entity/1, max_concurrency: System.schedulers_online())
      |> Enum.map(fn {:ok, entity} -> entity end)

    %{state | entities: updated_entities}
  end

  defp update_entity(entity) do
    # Logique de mouvement IA
    entity
  end
end
