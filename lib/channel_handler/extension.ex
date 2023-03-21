defmodule ChannelHandler.Extension do
  @moduledoc false

  use Spark.Dsl,
    default_extensions: [extensions: ChannelHandler.Dsl]

  def process_plugs(plugs, socket, payload, context) do
    Enum.reduce_while(plugs, {:cont, socket, payload, context}, fn plug,
                                                                   {:cont, socket, payload,
                                                                    context} ->
      dbg(plug)

      result =
        case plug.plug do
          {_, [fun: fun]} = fun_plug ->
            fun.(socket, payload, context, plug.options)

          {module, opts} when is_atom(module) ->
            module.call(socket, payload, context, opts)
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

      dbg(plugs)

      @handlers handlers
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
    quote location: :keep, bind_quoted: [delegate: delegate, plugs: plugs] do
      @delegate delegate
      @prefix delegate.prefix
      @plugs plugs
      def handle_in(@prefix <> event, payload, socket) do
        context = ChannelHandler.Extension.build_context(event)

        with {:cont, socket, payload, context} <-
               ChannelHandler.Extension.process_plugs(@plugs, socket, payload, context) do
          @delegate.module.handle_in(event, payload, context, socket)
        end
      end
    end
  end

  defmacro build_event(event, plugs) do
    quote location: :keep, bind_quoted: [event: event, plugs: plugs] do
      @name event.name
      @event event
      @plugs plugs
      def handle_in(@name, payload, socket) do
        context = ChannelHandler.Extension.build_context(@name)

        with {:cont, socket, payload, context} <-
               ChannelHandler.Extension.process_plugs(@plugs, socket, payload, context) do
          apply(@event.module, @event.function, [
            payload,
            context,
            socket
          ])
        end
      end
    end
  end

  defmacro build_handle(handle, plugs) do
    quote location: :keep, bind_quoted: [handle: handle, plugs: plugs] do
      @name handle.name
      @handle handle
      @plugs plugs

      def handle_in(@name, payload, socket) do
        context = ChannelHandler.Extension.build_context(@name)

        with {:cont, socket, payload, context} <-
               ChannelHandler.Extension.process_plugs(@plugs, socket, payload, context) do
          apply(@handle.function, [
            payload,
            context,
            socket
          ])
        end
      end
    end
  end

  defmacro build_group(group, plugs) do
    quote location: :keep, bind_quoted: [group: group, plugs: plugs] do
      plugs = plugs ++ group.plugs

      Enum.map(group.handlers, fn
        %ChannelHandler.Dsl.Delegate{} = delegate ->
          ChannelHandler.Extension.build_delegate(
            %{delegate | prefix: group.prefix <> delegate.prefix},
            plugs
          )

        %ChannelHandler.Dsl.Event{} = event ->
          ChannelHandler.Extension.build_event(
            %{event | name: group.prefix <> event.name},
            plugs
          )

        %ChannelHandler.Dsl.Handle{} = handle ->
          ChannelHandler.Extension.build_handle(
            %{handle | name: group.prefix <> handle.name},
            plugs
          )
      end)
    end
  end
end
