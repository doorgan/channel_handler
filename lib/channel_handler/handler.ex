defmodule ChannelsHandler.Handler do
  @moduledoc """
  A module implementing an event handler. Modules that `use ChannelHandler` already
  comply with this behaviour, so you should prefer that instead.
  """

  @callback handle_in(String.t(), term, map, Phoenix.Socket.t()) :: Phoenix.Channel.reply()
end
