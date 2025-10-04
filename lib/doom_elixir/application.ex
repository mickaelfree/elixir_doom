defmodule DoomElixir.Application do
  use Application

  def start(_type, _args) do
    children = [
      {Scenic,
       name: :main_viewport,
       size: {800, 600},
       default_scene: DoomElixir.Scene.Game,
       drivers: [
         [
           module: Scenic.Driver.Local,
           name: :local,
           window: [resizeable: false, title: "Doom Elixir"]
         ]
       ]}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
