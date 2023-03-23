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
          {_, [fun: fun]} ->
            fun.(socket, payload, context, plug.options)

          {module, _} when is_atom(module) ->
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

        %ChannelHandler.Dsl.Group{} = group ->
          @group group
          ChannelHandler.Extension.build_group(@group, @plugs)
      end)
    end
  end

  defmacro build_delegate(delegate, plugs) do
    quote location: :keep do
      @prefix unquote(delegate).prefix

      def handle_in(@prefix <> event, payload, socket) do
        context = ChannelHandler.Extension.build_context(event)

        with {:cont, socket, payload, context} <-
               ChannelHandler.Extension.process_plugs(unquote(plugs), socket, payload, context) do
          unquote(delegate).module.handle_in(event, payload, context, socket)
        end
      end
    end
  end

  defmacro build_event(event, plugs) do
    quote location: :keep do
      @name unquote(event).name

      def handle_in(@name, payload, socket) do
        context = ChannelHandler.Extension.build_context(@name)

        with {:cont, socket, payload, context} <-
               ChannelHandler.Extension.process_plugs(unquote(plugs), socket, payload, context) do
          apply(unquote(event).module, unquote(event).function, [
            payload,
            context,
            socket
          ])
        end
      end
    end
  end

  defmacro build_handle(handle, plugs) do
    quote location: :keep do
      @name unquote(handle).name

      def handle_in(@name, payload, socket) do
        context = ChannelHandler.Extension.build_context(@name)

        with {:cont, socket, payload, context} <-
               ChannelHandler.Extension.process_plugs(unquote(plugs), socket, payload, context) do
          apply(unquote(handle).function, [
            payload,
            context,
            socket
          ])
        end
      end
    end
  end

  defmacro build_group(group, parent_plugs) do
    quote location: :keep do
      Enum.map(unquote(group).handlers, fn
        %ChannelHandler.Dsl.Delegate{} = delegate ->
          @delegate delegate
          ChannelHandler.Extension.build_delegate(
            %{@delegate | prefix: unquote(group).prefix <> @delegate.prefix},
            unquote(group).plugs ++ unquote(parent_plugs)
          )

        %ChannelHandler.Dsl.Event{} = event ->
          @event event
          ChannelHandler.Extension.build_event(
            %{@event | name: unquote(group).prefix <> @event.name},
            unquote(group).plugs ++ unquote(parent_plugs)
          )

        %ChannelHandler.Dsl.Handle{} = handle ->
          @handle handle
          ChannelHandler.Extension.build_handle(
            %{@handle | name: unquote(group).prefix <> @handle.name},
            unquote(group).plugs ++ unquote(parent_plugs)
          )
      end)
    end
  end
end
