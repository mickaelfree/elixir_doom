defmodule DoomElixir.NPC do
  use GenServer

  @moduledoc """
  NPC autonome avec IA - chaque NPC est un processus Elixir indépendant
  Si un NPC crash, il est automatiquement redémarré par le superviseur
  """

  defstruct [:id, :position, :target, :state, :health, :behavior]

  # Client API
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def get_position(pid) do
    GenServer.call(pid, :get_position)
  end

  def set_target(pid, target_position) do
    GenServer.cast(pid, {:set_target, target_position})
  end

  # Server Callbacks
  @impl true
  def init(opts) do
    npc = %__MODULE__{
      id: Keyword.get(opts, :id),
      position: Keyword.get(opts, :position, {5.0, 5.0}),
      target: nil,
      state: :idle,
      health: 100,
      behavior: Keyword.get(opts, :behavior, :patrol)
    }

    # Tick périodique pour l'IA
    :timer.send_interval(100, self(), :ai_tick)

    {:ok, npc}
  end

  @impl true
  def handle_call(:get_position, _from, npc) do
    {:reply, npc.position, npc}
  end

  @impl true
  def handle_cast({:set_target, target}, npc) do
    {:noreply, %{npc | target: target, state: :chasing}}
  end

  @impl true
  def handle_info(:ai_tick, npc) do
    new_npc = execute_ai_behavior(npc)
    {:noreply, new_npc}
  end

  # IA Behavior
  defp execute_ai_behavior(%{behavior: :patrol, state: :idle} = npc) do
    # Patrol aléatoire
    {x, y} = npc.position
    new_x = x + (:rand.uniform() - 0.5) * 0.1
    new_y = y + (:rand.uniform() - 0.5) * 0.1

    %{npc | position: {new_x, new_y}}
  end

  defp execute_ai_behavior(%{behavior: :patrol, state: :chasing, target: target} = npc) do
    # Poursuivre le joueur
    {nx, ny} = npc.position
    {tx, ty} = target

    dx = tx - nx
    dy = ty - ny
    distance = :math.sqrt(dx * dx + dy * dy)

    if distance > 0.1 do
      # Normaliser et déplacer vers la cible
      new_x = nx + dx / distance * 0.05
      new_y = ny + dy / distance * 0.05
      %{npc | position: {new_x, new_y}}
    else
      %{npc | state: :idle, target: nil}
    end
  end

  defp execute_ai_behavior(npc), do: npc
end

defmodule DoomElixir.NPCSupervisor do
  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def spawn_npc(position, behavior \\ :patrol) do
    child_spec = %{
      id: DoomElixir.NPC,
      start: {DoomElixir.NPC, :start_link, [[position: position, behavior: behavior]]},
      restart: :transient
    }

    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end
end
