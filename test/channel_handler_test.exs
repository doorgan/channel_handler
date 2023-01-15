defmodule ChannelHandlerTest do
  use ExUnit.Case
  doctest ChannelHandler

  test "greets the world" do
    assert ChannelHandler.hello() == :world
  end
end
