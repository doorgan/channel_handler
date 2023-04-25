defmodule ChannelHandler.RouterTest do
  use ExUnit.Case, async: true

  test "routes calls to the right handlers" do
    defmodule TestRouter do
      use ChannelHandler.Router

      alias ChannelHandler.Context

      router do
        event("event", ChannelHandler.RouterTest.TestHandler, :event_fun)
        event("catchall_event:*", ChannelHandler.RouterTest.TestHandler, :event_fun_catchall)

        delegate("delegate", ChannelHandler.RouterTest.TestHandler)

        handle("handler", fn _payload, context, _socket ->
          assert %Context{} = context
          assert context.event == "handler"
          :handler
        end)

        handle("catchall:*", fn event, _payload, context, _socket ->
          assert %Context{} = context
          assert event == "handler"
          assert context.event == "catchall:handler"
          :catchall_handler
        end)

        scope "scoped:" do
          event("event", ChannelHandler.RouterTest.ScopedHandler, :event_fun)
          event("catchall_event:*", ChannelHandler.RouterTest.ScopedHandler, :event_fun_catchall)
          delegate("delegate", ChannelHandler.RouterTest.ScopedHandler)

          handle("handler", fn _payload, context, _socket ->
            assert context.event == "scoped:handler"
            assert %Context{} = context
            :scoped_handler
          end)
        end

        scope "with_plug:" do
          plug(&noop_plug/4)

          event("event", ChannelHandler.RouterTest.WithPlugHandler, :event_fun)

          event(
            "catchall_event:*",
            ChannelHandler.RouterTest.WithPlugHandler,
            :event_fun_catchall
          )

          delegate("delegate", ChannelHandler.RouterTest.WithPlugHandler)

          handle("handler", fn _payload, context, _socket ->
            assert context.event == "with_plug:handler"
            assert %Context{} = context
            :with_plug_handler
          end)
        end

        scope do
          plug(&noop_plug/4)

          handle("no_scope", fn _payload, context, _socket ->
            assert context.event == "no_scope"
            assert %Context{} = context
            :no_scope
          end)
        end
      end

      def noop_plug(socket, payload, context, _opts) do
        assert %Context{} = context
        send(self(), :plug_called)

        {:cont, socket, payload, context}
      end
    end

    defmodule TestHandler do
      alias ChannelHandler.Context

      def event_fun(_payload, context, _socket) do
        assert %Context{} = context
        assert context.event == "event"
        :event
      end

      def event_fun_catchall(event, _payload, context, _socket) do
        assert %Context{} = context
        assert event == "event_name"
        assert context.event == "catchall_event:event_name"
        :event_catchall
      end

      def handle_in(_event, _payload, context, _socket) do
        assert %Context{} = context
        assert context.event == "delegate"
        :delegate
      end
    end

    defmodule ScopedHandler do
      alias ChannelHandler.Context

      def event_fun(_payload, context, _socket) do
        assert %Context{} = context
        assert context.event == "scoped:event"
        :scoped_event
      end

      def event_fun_catchall(event, _payload, context, _socket) do
        assert %Context{} = context
        assert event == "event_name"
        assert context.event == "scoped:catchall_event:event_name"
        :scoped_event_catchall
      end

      def handle_in(_event, _payload, context, _socket) do
        assert %Context{} = context
        assert context.event == "scoped:delegate"
        :scoped_delegate
      end
    end

    defmodule WithPlugHandler do
      use ChannelHandler.Handler

      alias ChannelHandler.Context

      plug((&module_plug/4) when action: [:event_fun, :event_fun_catchall])

      def event_fun(_payload, context, _socket) do
        assert %Context{} = context
        assert context.event == "with_plug:event"
        :with_plug_event
      end

      def event_fun_catchall(event, _payload, context, _socket) do
        assert %Context{} = context
        assert event == "event_name"
        assert context.event == "with_plug:catchall_event:event_name"
        :with_plug_event_catchall
      end

      def handle_in(_event, _payload, context, _socket) do
        assert %Context{} = context
        assert context.event == "with_plug:delegate"
        :with_plug_delegate
      end

      def module_plug(socket, payload, context, _opts) do
        assert %Context{} = context
        send(self(), :module_plug_called)

        {:cont, socket, payload, context}
      end
    end

    assert TestRouter.handle_in("event", %{}, :socket) == :event
    assert TestRouter.handle_in("catchall_event:event_name", %{}, :socket) == :event_catchall
    assert TestRouter.handle_in("delegate", %{}, :socket) == :delegate
    assert TestRouter.handle_in("handler", %{}, :socket) == :handler

    assert TestRouter.handle_in("scoped:event", %{}, :socket) == :scoped_event

    assert TestRouter.handle_in("scoped:catchall_event:event_name", %{}, :socket) ==
             :scoped_event_catchall

    assert TestRouter.handle_in("scoped:delegate", %{}, :socket) == :scoped_delegate
    assert TestRouter.handle_in("scoped:handler", %{}, :socket) == :scoped_handler

    assert TestRouter.handle_in("with_plug:event", %{}, :socket) == :with_plug_event
    assert_receive :plug_called
    assert_receive :module_plug_called

    assert TestRouter.handle_in("with_plug:catchall_event:event_name", %{}, :socket) ==
             :with_plug_event_catchall

    assert_receive :plug_called
    assert_receive :module_plug_called

    assert TestRouter.handle_in("with_plug:delegate", %{}, :socket) == :with_plug_delegate
    assert_receive :plug_called
    refute_receive :module_plug_called

    assert TestRouter.handle_in("with_plug:handler", %{}, :socket) == :with_plug_handler
    assert_receive :plug_called
    refute_receive :module_plug_called

    assert TestRouter.handle_in("no_scope", %{}, :socket) == :no_scope
    assert_receive :plug_called
  end
end
