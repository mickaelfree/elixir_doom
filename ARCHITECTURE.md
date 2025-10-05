# 🚀 Architecture Distribuée - DoomElixir

## Exploiter la Puissance d'Elixir pour le Raycasting

### 💡 Concepts Clés

#### 1. **Concurrence Massive avec BEAM**
```
┌─────────────────────────────────────┐
│   1 Joueur = 1 Processus Elixir     │
│   1 NPC = 1 Processus Elixir        │
│   1 Projectile = 1 Processus Elixir │
├─────────────────────────────────────┤
│   → Des millions de processus       │
│   → Isolation totale (crash-safe)   │
│   → Pas de locks, pas de mutex      │
└─────────────────────────────────────┘
```

#### 2. **Distribution Multi-Nodes**
```elixir
# Node 1: Game Logic Server
Node.connect(:"game@server1.com")

# Node 2: AI & Physics
Node.connect(:"ai@server2.com")

# Node 3: Map Generation
Node.connect(:"mapgen@server3.com")

# Nodes communiquent automatiquement!
```

#### 3. **Raycasting Parallèle avec Nx**
```elixir
defmodule DoomElixir.ParallelRaycaster do
  import Nx.Defn

  # Compiler avec EXLA pour utiliser le GPU!
  defn cast_rays_gpu(player_pos, player_angle, num_rays) do
    # Tous les rayons calculés en PARALLÈLE sur GPU
    rays = Nx.iota({num_rays})
    angles = player_angle + (rays / num_rays - 0.5) * (Nx.Constants.pi() / 3)

    # Calcul vectorisé
    dir_x = Nx.cos(angles)
    dir_y = Nx.sin(angles)

    # Retourner distances (DDA algorithm vectorisé)
    trace_rays_parallel(player_pos, {dir_x, dir_y})
  end
end
```

### 🎮 Cas d'Usage Incroyables

#### **1. MMO Raycasting**
- **1000+ joueurs** dans le même monde
- Chaque joueur voit uniquement ce qui est proche (vision culling)
- **PubSub** pour broadcaster les états
- **Registry** pour trouver les joueurs par zone

```elixir
# Trouver tous les joueurs dans une zone
{:via, Registry, {DoomElixir.PlayerRegistry, {zone_x, zone_y}}}
```

#### **2. Battle Royale avec Shrinking Zone**
- **GenStage** pour pipeline de game events
- **Task.Supervisor** pour spawner des items
- Zone qui rétrécit = processus qui tue les joueurs hors zone

#### **3. Roguelike Procédural Infini**
- **Agent** pour cache de chunks générés
- **DynamicSupervisor** pour spawner/despawner chunks
- Génération lazy à la Minecraft

```elixir
defmodule DoomElixir.ChunkManager do
  use Agent

  def get_chunk({x, y}) do
    Agent.get_and_update(__MODULE__, fn cache ->
      case Map.get(cache, {x, y}) do
        nil ->
          # Générer le chunk en lazy
          chunk = DoomElixir.ProceduralMap.generate_chunk(x, y)
          {chunk, Map.put(cache, {x, y}, chunk)}

        chunk ->
          {chunk, cache}
      end
    end)
  end
end
```

#### **4. IA Swarm avec Horde**
- **Horde.DynamicSupervisor** pour distribution automatique
- NPCs équilibrés sur tous les nodes
- Si un node crash, les NPCs migrent automatiquement!

```elixir
# Spawn 1000 NPCs - distribués automatiquement
1..1000
|> Task.async_stream(fn i ->
  Horde.DynamicSupervisor.start_child(
    DoomElixir.NPCHorde,
    {DoomElixir.NPC, position: random_position()}
  )
end)
|> Stream.run()
```

### 🔥 Optimisations Extrêmes

#### **ETS pour Cache Ultra-Rapide**
```elixir
# Raycasting results cachés dans ETS
:ets.new(:raycast_cache, [:set, :public, :named_table])

# Lookup en O(1) - des millions par seconde
:ets.lookup(:raycast_cache, {player_pos, angle})
```

#### **Binary Pattern Matching pour Protocoles**
```elixir
# Network protocol ultra-efficace
defmodule DoomElixir.Protocol do
  # Encoder position en 12 bytes
  def encode_position(x, y, angle) do
    <<x::float-32, y::float-32, angle::float-32>>
  end

  # Decoder avec pattern matching
  def decode(<<x::float-32, y::float-32, angle::float-32, rest::binary>>) do
    {{x, y, angle}, rest}
  end
end
```

#### **Phoenix LiveView pour UI Temps Réel**
```elixir
defmodule DoomElixirWeb.GameLive do
  use Phoenix.LiveView

  # UI update à 60 FPS via WebSocket
  def mount(_params, _session, socket) do
    :timer.send_interval(16, self(), :tick)
    {:ok, assign(socket, game_state: initial_state())}
  end

  def handle_info(:tick, socket) do
    # Broadcast à TOUS les joueurs connectés
    {:noreply, push_event(socket, "game_tick", %{state: get_state()})}
  end
end
```

### 🌟 Architecture Finale

```
┌─────────────────────────────────────────────────┐
│                  Load Balancer                   │
└─────────────────────┬───────────────────────────┘
                      │
        ┌─────────────┴─────────────┐
        │                           │
   ┌────▼────┐                 ┌────▼────┐
   │ Node 1  │◄───────────────►│ Node 2  │
   │         │                 │         │
   │ Players │                 │   AI    │
   │ 1-1000  │                 │ NPCs    │
   └────┬────┘                 └────┬────┘
        │                           │
        └─────────────┬─────────────┘
                      │
              ┌───────▼────────┐
              │   PostgreSQL   │
              │   (via Ecto)   │
              │                │
              │  • Persistance │
              │  • Leaderboards│
              │  • Replays     │
              └────────────────┘
```

### 🎯 Résultat Final

Avec Elixir, votre simple raycasting devient:
- **Scalable** horizontalement (ajoutez des serveurs)
- **Fault-tolerant** (un crash ne tue pas le jeu)
- **Temps-réel** (latence < 50ms pour 10k+ joueurs)
- **Distribué** (calculs sur CPU + GPU + Cloud)

**Le raycasting simple + Elixir = MMO AAA possible!** 🚀
