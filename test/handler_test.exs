defmodule ChannelHandler.HandlerTest do
  use ExUnit.Case, async: true

  describe "plug/2" do
    test "supports guards" do
      defmodule GuardsRouter do
        use ChannelHandler.Router

        event("create", ChannelHandler.HandlerTest.GuardsHandler, :create)
        event("delete", ChannelHandler.HandlerTest.GuardsHandler, :delete)

        delegate("delegated:", ChannelHandler.HandlerTest.GuardsHandler)
      end

      defmodule GuardsHandler do
        use ChannelHandler.Handler

        alias ChannelHandler.Context

        plug((&noop/4) when action in [:create] or event in ["update"])

        plug(ChannelHandler.HandlerTest.ModulePlug when action in [:create])

        def create(_payload, context, socket) do
          {:reply, {:ok, context}, socket}
        end

        def delete(_payload, context, socket) do
          {:reply, {:ok, context}, socket}
        end

        def handle_in(_event, _payload, context, socket) do
          {:reply, {:ok, context}, socket}
        end

        def noop(socket, payload, context, _opts) do
          context = Context.assign(context, :called, true)
          {:cont, socket, payload, context}
        end
      end

      defmodule ModulePlug do
        alias ChannelHandler.Context

        def call(socket, payload, context, _opts) do
          context = Context.assign(context, :module_plug_called, true)
          {:cont, socket, payload, context}
        end
      end

      assert {:reply, {:ok, context}, _socket} =
               GuardsRouter.handle_in("create", "payload", %Phoenix.Socket{})

      assert context.bindings[:called] == true
      assert context.bindings[:module_plug_called] == true

      assert {:reply, {:ok, context}, _socket} =
               GuardsRouter.handle_in("delete", "payload", %Phoenix.Socket{})

      refute context.bindings[:called] == true

      assert {:reply, {:ok, context}, _socket} =
               GuardsRouter.handle_in("delegated:update", "payload", %Phoenix.Socket{})

      assert context.bindings[:called] == true

      assert {:reply, {:ok, context}, _socket} =
               GuardsRouter.handle_in("delegated:delete", "payload", %Phoenix.Socket{})

      refute context.bindings[:called] == true
    end
  end
end
