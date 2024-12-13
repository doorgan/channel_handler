defmodule ChannelHandler.Extension do
  @moduledoc false

  use Spark.Dsl,
    default_extensions: [extensions: ChannelHandler.Dsl]

  def apply_plug({module, function}, socket, payload, context, opts)
      when is_atom(module) and is_atom(function) do
    apply(module, function, [socket, payload, context, opts])
  end

  def apply_plug(fun, socket, payload, context, opts) when is_function(fun, 4) do
    fun.(socket, payload, context, opts)
  end

  def apply_plug({_, [fun: fun]}, socket, payload, context, opts) do
    fun.(socket, payload, context, opts)
  end

  def apply_plug({module, _}, socket, payload, context, opts) when is_atom(module) do
    module.call(socket, payload, context, opts)
  end

  def apply_plug(module, socket, payload, context, opts) when is_atom(module) do
    module.call(socket, payload, context, opts)
  end

  def process_plugs(plugs, socket, payload, context) do
    Enum.reduce_while(plugs, {:cont, socket, payload, context}, fn plug,
                                                                   {:cont, socket, payload,
                                                                    context} ->
      result = apply_plug(plug.plug, socket, payload, context, plug.options)

      case result do
        {:cont, socket, payload, context} -> {:cont, {:cont, socket, payload, context}}
        {:reply, reply, socket} -> {:halt, {:reply, reply, socket}}
        {:noreply, socket} -> {:halt, {:noreply, socket}}
      end
    end)
  end

  def build_context(attrs) do
    struct(ChannelHandler.Context, attrs)
  end

  def handle_before_compile(_opts) do
    quote location: :keep, generated: true, unquote: false do
      @_channel Spark.Dsl.Extension.get_opt(__MODULE__, [:join], :channel)
      @_join_fun Spark.Dsl.Extension.get_opt(__MODULE__, [:join], :join)

      if @_join_fun do
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

  defmacro build_delegate(delegate, plugs) do
    quote location: :keep do
      @prefix unquote(delegate).prefix

      def handle_in(@prefix <> event, payload, socket) do
        context =
          ChannelHandler.Extension.build_context(event: event, full_event: @prefix <> event)

        module_plugs =
          unquote(delegate).module.__info__(:attributes)
          |> Keyword.get_values(:plugs)
          |> List.flatten()

        with {:cont, socket, payload, context} <-
               ChannelHandler.Extension.process_plugs(
                 unquote(plugs) ++ module_plugs,
                 socket,
                 payload,
                 context
               ) do
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
    full_event = "#{prefix}#{event_name}"

    context =
      ChannelHandler.Extension.build_context(
        event: full_event,
        full_event: full_event,
        action: event.function
      )

    module_plugs =
      event.module.__info__(:attributes)
      |> Keyword.get_values(:plugs)
      |> List.flatten()

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
    context = ChannelHandler.Extension.build_context(full_event: event, event: event)
    telemetry_meta = %{event: event, prefix: prefix}

    :telemetry.span([:channel_handler, :handle], telemetry_meta, fn ->
      result =
        with {:cont, socket, payload, context} <-
               ChannelHandler.Extension.process_plugs(plugs, socket, payload, context) do
          if prefix do
            apply(handle.function, [event, payload, context, socket])
          else
            apply(handle.function, [payload, context, socket])
          end
        end

      {result, telemetry_meta}
    end)
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
