defmodule ChannelsHandler.Plug do
  @callback call(Phoenix.Socket.t(), term, map) ::
              {:ok, Phoenix.Socket.t(), term, map} | {:error, term()}
end
