defmodule ChannelHandler do
  defmacro __using__(:handler) do
    quote do
      Module.register_attribute(__MODULE__, :plugs, accumulate: true, persist: true)

      import ChannelHandler.Extension, only: [plug: 1, plug: 2]
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
