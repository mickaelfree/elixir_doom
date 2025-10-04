defmodule DoomElixirTest do
  use ExUnit.Case
  doctest DoomElixir

  test "greets the world" do
    assert DoomElixir.hello() == :world
  end
end
