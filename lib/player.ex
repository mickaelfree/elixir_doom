defmodule DoomElixir.Player do
  defstruct [:x, :y, :angle, :fov]

  def new(x, y, angle) do
    %__MODULE__{x: x, y: y, angle: angle, fov: :math.pi() / 3}
  end
end
