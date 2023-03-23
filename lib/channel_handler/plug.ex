defmodule ChannelHandler.Plug do
  @moduledoc """
  A `ChannelHandler.Plug`, is a function or module that takes the connection
  socket, the payload and the current handler bindings, and either returns a
  modified version of each, or directly replies to the client, halting further
  processing.

  The plug can either be a module implementing the `ChannelHandler.Plug` behaviour,
  or an function of arity 4

  ## Examples

      def call(socket, _payload, _bindings, _opts) do
        case authenticated?(socket) do
          {:cont, socket, payload, bindings}
        else
          {:reply, {:error, "Not authenticated"}, socket}
        end
      end
  """

  @callback call(Phoenix.Socket.t(), payload :: term, bindings :: map, Keyword.t()) ::
              {:cont, Phoenix.Socket.t(), term, map}
              | {:reply, term(), Phoenix.Socket.t()}
              | {:noreply, Phoenix.Socket.t()}
end
