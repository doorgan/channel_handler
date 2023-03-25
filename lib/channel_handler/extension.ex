defmodule ChannelHandler.Extension do
  @moduledoc false

  use Spark.Dsl,
    default_extensions: [extensions: ChannelHandler.Dsl]

  @doc """
  Registers a plug for the current module
  """
  defmacro plug(plug)

  defmacro plug({:when, _, [plug, guards]}) do
    plug(plug, [], guards, __CALLER__)
  end

  defmacro plug(plug) do
    plug(plug, [], [], __CALLER__)
  end

  defmacro plug(plug, opts)

  defmacro plug(plug, {:when, _, [opts, guards]}) do
    plug(plug, opts, guards, __CALLER__)
  end

  defmacro plug(plug, opts) do
    plug(plug, opts, [], __CALLER__)
  end

  def plug(plug, opts, guards, env) do
    {value, function} = Spark.CodeHelpers.lift_functions(plug, :module_plug, env)

    expanded_value =
      if Macro.quoted_literal?(value) do
        Macro.prewalk(value, &expand_alias(&1, env))
      else
        value
      end

    quote do
      unquote(function)

      @plugs %ChannelHandler.Dsl.Plug{
        plug: unquote(expanded_value),
        options: unquote(opts),
        guards: unquote(guards)
      }
    end
  end

  defp expand_alias({:__aliases__, _, _} = alias, env),
    do: Macro.expand(alias, %{env | function: {:__attr__, 3}})

  defp expand_alias(other, _env), do: other

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

        %ChannelHandler.Dsl.Group{} = group ->
          @group group
          ChannelHandler.Extension.build_group(@group, @plugs)
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
        context = ChannelHandler.Extension.build_context(event)

        module_plugs =
          Keyword.get_values(@event.module.__info__(:attributes), :plugs)
          |> List.flatten()
          |> Enum.filter(fn plug ->
            ChannelHandler.Extension.check_event(plug, @name)
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
      @name unquote(event).name
      @event unquote(event)

      def handle_in(@name, payload, socket) do
        context = ChannelHandler.Extension.build_context(@name)

        module_plugs =
          Keyword.get_values(@event.module.__info__(:attributes), :plugs)
          |> List.flatten()
          |> Enum.filter(fn plug ->
            ChannelHandler.Extension.check_action(plug, @event.function) and
              ChannelHandler.Extension.check_event(plug, @name)
          end)

        with {:cont, socket, payload, context} <-
               ChannelHandler.Extension.process_plugs(
                 unquote(plugs) ++ module_plugs,
                 socket,
                 payload,
                 context
               ) do
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
