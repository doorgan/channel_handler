defmodule ChannelHandler.Handler do
  @moduledoc """
  A module implementing an event handler.
  """

  @callback handle_in(String.t(), term, map, Phoenix.Socket.t()) :: Phoenix.Channel.reply()
end
