defmodule ChannelHandler.Extension do
  @moduledoc false

  use Spark.Dsl,
    default_extensions: [extensions: ChannelHandler.Dsl]

  def process_plugs(plugs, socket, payload, context) do
    Enum.reduce_while(plugs, {:cont, socket, payload, context}, fn plug,
                                                                   {:cont, socket, payload,
                                                                    context} ->
      result =
        case plug.plug do
          {module, function} when is_atom(module) and is_atom(function) ->
            apply(module, function, [socket, payload, context, plug.options])

          fun when is_function(fun, 4) ->
            fun.(socket, payload, context, plug.options)

          {_, [fun: fun]} ->
            fun.(socket, payload, context, plug.options)

          {module, _} when is_atom(module) ->
            module.call(socket, payload, context, plug.options)

          module when is_atom(module) ->
            module.call(socket, payload, context, plug.options)
        end

      case result do
        {:cont, socket, payload, context} -> {:cont, {:cont, socket, payload, context}}
        {:reply, reply, socket} -> {:halt, {:reply, reply, socket}}
        {:noreply, socket} -> {:halt, {:noreply, socket}}
      end
    end)
  end

  def build_context(event) do
    %ChannelHandler.Context{bindings: %{}, event: event}
  end

  def handle_before_compile(_opts) do
    quote location: :keep, generated: true, unquote: false do
      @_channel Spark.Dsl.Extension.get_opt(__MODULE__, [:join], :channel)
      @_join_fun Spark.Dsl.Extension.get_opt(__MODULE__, [:join], :handler)

      if @_channel && @_join_fun do
        def join(topic, payload, socket) do
          socket = Phoenix.Socket.assign(socket, :__channel__, @_channel)
          apply(@_join_fun, [topic, payload, socket])
        end
      end

      router = Spark.Dsl.Extension.get_entities(__MODULE__, [:router])

      {plugs, handlers} = Enum.split_with(router, &is_struct(&1, ChannelHandler.Dsl.Plug))

      @plugs plugs
      def __plugs__() do
        @plugs
      end

      Enum.map(handlers, fn
        %ChannelHandler.Dsl.Delegate{} = delegate ->
          @delegate delegate
          ChannelHandler.Extension.build_delegate(@delegate, @plugs)

        %ChannelHandler.Dsl.Event{} = event ->
          @event event
          ChannelHandler.Extension.build_event(@event, @plugs)

        %ChannelHandler.Dsl.Handle{} = handle ->
          @handle handle
          ChannelHandler.Extension.build_handle(@handle, @plugs)

        %ChannelHandler.Dsl.Scope{} = scope ->
          @scope scope
          ChannelHandler.Extension.build_scope(@scope, @plugs)
      end)
    end
  end

  def check_action(plug, event_action) do
    case plug.guards[:action] do
      nil -> true
      actions when is_list(actions) -> event_action in actions
      action when is_atom(action) -> event_action == action
      _ -> true
    end
  end

  def check_event(plug, event_name) do
    case plug.guards[:event] do
      nil -> true
      events when is_list(events) -> event_name in events
      event when is_binary(event) -> event_name == event
      _ -> true
    end
  end

  defmacro build_delegate(delegate, plugs) do
    quote location: :keep do
      @prefix unquote(delegate).prefix

      def handle_in(@prefix <> event, payload, socket) do
        context = ChannelHandler.Extension.build_context(@prefix <> event)

        module_plugs =
          Keyword.get_values(unquote(delegate).module.__info__(:attributes), :plugs)
          |> List.flatten()
          |> Enum.filter(fn plug ->
            ChannelHandler.Extension.check_event(plug, event)
          end)

        with {:cont, socket, payload, context} <-
               ChannelHandler.Extension.process_plugs(unquote(plugs), socket, payload, context) do
          unquote(delegate).module.handle_in(event, payload, context, socket)
        end
      end
    end
  end

  defmacro build_event(event, plugs) do
    quote location: :keep, generated: true do
      case String.split(unquote(event).name, "*") do
        [bare_event] ->
          @name bare_event
          def handle_in(@name, payload, socket) do
            ChannelHandler.Extension.perform_event(
              @name,
              nil,
              payload,
              socket,
              unquote(event),
              unquote(plugs)
            )
          end

        [prefix, ""] ->
          @prefix prefix
          def handle_in(@prefix <> event, payload, socket) do
            ChannelHandler.Extension.perform_event(
              event,
              @prefix,
              payload,
              socket,
              unquote(event),
              unquote(plugs)
            )
          end

        _ ->
          raise ArgumentError, "channels using splat patterns must end with *"
      end
    end
  end

  def perform_event(event_name, prefix, payload, socket, event, plugs) do
    context = ChannelHandler.Extension.build_context("#{prefix}#{event_name}")

    module_plugs =
      Keyword.get_values(event.module.__info__(:attributes), :plugs)
      |> List.flatten()
      |> Enum.filter(fn plug ->
        ChannelHandler.Extension.check_action(plug, event.function) and
          ChannelHandler.Extension.check_event(plug, event_name)
      end)

    with {:cont, socket, payload, context} <-
           ChannelHandler.Extension.process_plugs(
             plugs ++ module_plugs,
             socket,
             payload,
             context
           ) do
      if prefix do
        apply(event.module, event.function, [
          event_name,
          payload,
          context,
          socket
        ])
      else
        apply(event.module, event.function, [
          payload,
          context,
          socket
        ])
      end
    end
  end

  defmacro build_handle(handle, plugs) do
    quote location: :keep do
      case String.split(unquote(handle).name, "*") do
        [bare_event] ->
          if Function.info(unquote(handle).function)[:arity] != 3 do
            raise ArgumentError, "bare event handlers must have an arity of 3"
          end

          @name bare_event
          def handle_in(@name, payload, socket) do
            ChannelHandler.Extension.perform_handle(
              @name,
              nil,
              payload,
              socket,
              unquote(handle),
              unquote(plugs)
            )
          end

        [prefix, ""] ->
          if Function.info(unquote(handle).function)[:arity] != 4 do
            raise ArgumentError, "event handlers using splat patterns must have an arity of 4"
          end

          @prefix prefix
          def handle_in(@prefix <> rest, payload, socket) do
            ChannelHandler.Extension.perform_handle(
              rest,
              @prefix,
              payload,
              socket,
              unquote(handle),
              unquote(plugs)
            )
          end

        _ ->
          raise ArgumentError, "channels using splat patterns must end with *"
      end
    end
  end

  def perform_handle(event, prefix, payload, socket, handle, plugs) do
    context = ChannelHandler.Extension.build_context(event)

    with {:cont, socket, payload, context} <-
           ChannelHandler.Extension.process_plugs(plugs, socket, payload, context) do
      if prefix do
        apply(handle.function, [event, payload, context, socket])
      else
        apply(handle.function, [
          payload,
          context,
          socket
        ])
      end
    end
  end

  defmacro build_scope(scope, parent_plugs) do
    quote location: :keep do
      Enum.map(unquote(scope).handlers, fn
        %ChannelHandler.Dsl.Delegate{} = delegate ->
          @delegate delegate
          ChannelHandler.Extension.build_delegate(
            %{@delegate | prefix: unquote(scope).prefix <> @delegate.prefix},
            unquote(scope).plugs ++ unquote(parent_plugs)
          )

        %ChannelHandler.Dsl.Event{} = event ->
          @event event
          ChannelHandler.Extension.build_event(
            %{@event | name: unquote(scope).prefix <> @event.name},
            unquote(scope).plugs ++ unquote(parent_plugs)
          )

        %ChannelHandler.Dsl.Handle{} = handle ->
          @handle handle
          ChannelHandler.Extension.build_handle(
            %{@handle | name: unquote(scope).prefix <> @handle.name},
            unquote(scope).plugs ++ unquote(parent_plugs)
          )
      end)
    end
  end
end
