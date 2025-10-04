defmodule DoomElixir.MixProject do
  use Mix.Project

  def project do
    [
      app: :doom_elixir,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {DoomElixir.Application, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:scenic, "~> 0.11"},
      {:scenic_driver_local, "~> 0.11"},
      {:nx, "~> 0.6"},
      {:exla, "~> 0.6"}
    ]
  end
end
