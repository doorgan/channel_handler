defmodule ChannelHandler.Router do
  @moduledoc """
  For documentation about the router, check `ChannelHandler.Dsl`.

  To add a router to your Channel, do

      use ChannelHandler.Router

      router do
        # Your events here
      end
  """

  defmacro __using__(_opts) do
    quote do
      use ChannelHandler.Extension

      import Phoenix.Socket, only: [assign: 2, assign: 3]

      import Phoenix.Channel,
        only: [
          broadcast: 3,
          broadcast!: 3,
          broadcast_from: 3,
          broadcast_from!: 3,
          push: 3,
          reply: 2
        ]
    end
  end
end
