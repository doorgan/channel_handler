defmodule ChannelsHandler.Handler do
  @callback handle_in(String.t(), {term, map}, Phoenix.Socket.t()) :: Phoenix.Channel.reply()
  @callback handle_in({term, map}, Phoenix.Socket.t()) :: Phoenix.Channel.reply()
end
