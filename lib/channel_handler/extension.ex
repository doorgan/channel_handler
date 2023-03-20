defmodule ChannelHandler.Extension do
  use Spark.Dsl,
    default_extensions: [extensions: ChannelHandler.Dsl]

  alias ChannelHandler.Dsl

  def explain(_, _), do: nil

  @doc false
  def get_handler(match_or_event) do
    case match_or_event.handler do
      {_, [fun: handler_fun]} -> handler_fun
      {module, _} -> module
    end
  end

  @doc false
  def process_plugs(plugs, socket, payload, bindings, env) do
    Enum.reduce_while(plugs, {:cont, socket, payload, bindings}, fn plug,
                                                                    {:cont, socket, payload,
                                                                     bindings} ->
      result =
        case plug.function do
          {_, [fun: fun]} ->
            fun.(socket, payload, bindings, [])

          {atom, opts} when is_atom(atom) ->
            if atom |> to_string() |> String.starts_with?("Elixir.") do
              atom.call(socket, payload, bindings, opts)
            else
              apply(env.module, atom, [socket, payload, bindings, opts])
            end
        end

      case result do
        {:cont, socket, payload, bindings} -> {:cont, {:cont, socket, payload, bindings}}
        {:reply, reply, socket} -> {:halt, {:reply, reply, socket}}
        {:noreply, socket} -> {:halt, {:noreply, socket}}
      end
    end)
  end

  @doc false
  def handle_before_compile(_opts) do
    quote location: :keep, generated: true do
      @_channel Spark.Dsl.Extension.get_opt(__MODULE__, [:join], :channel)
      @_join_fun Spark.Dsl.Extension.get_opt(__MODULE__, [:join], :handler)

      if @_channel && @_join_fun do
        def join(topic, payload, socket) do
          socket = Phoenix.Socket.assign(socket, :__channel__, @_channel)
          apply(@_join_fun, [topic, payload, socket])
        end
      end

      for match_or_event <- Spark.Dsl.Extension.get_entities(__MODULE__, [:handlers]) do
        handler = ChannelHandler.Extension.get_handler(match_or_event)
        plugs = match_or_event.plugs

        case match_or_event do
          %Dsl.Match{prefix: prefix} ->
            @prefix prefix
            @handler handler
            @plugs plugs
            def handle_in(@prefix <> event, payload, socket) do
              {payload, bindings} =
                case payload do
                  {:binary, _} -> {payload, %{}}
                  {payload, bindings} -> {payload, bindings}
                  payload -> {payload, %{}}
                end

              bindings =
                Map.update(bindings, :__event__, @prefix <> event, &(&1 <> @prefix <> event))

              result =
                ChannelHandler.Extension.process_plugs(
                  @plugs,
                  socket,
                  payload,
                  bindings,
                  __ENV__
                )

              case result do
                {:cont, socket, payload, bindings} ->
                  case @handler do
                    fun when is_function(fun) ->
                      fun.(event, payload, bindings, socket)

                    {m, f, a} ->
                      apply(m, f, [event, {payload, bindings}, socket])

                    module when is_atom(module) ->
                      module.handle_in(event, {payload, bindings}, socket)
                  end

                {:reply, reply, socket} ->
                  {:reply, reply, socket}

                {:noreply, socket} ->
                  {:noreply, socket}
              end
            end

          %Dsl.Event{name: name} ->
            @name name
            @handler handler
            @plugs plugs
            def handle_in(@name, payload, socket) do
              {payload, bindings} =
                case payload do
                  {:binary, _} -> {payload, %{}}
                  {payload, bindings} -> {payload, bindings}
                  payload -> {payload, %{}}
                end

              bindings = Map.put_new(bindings, :__event__, @name)

              result =
                ChannelHandler.Extension.process_plugs(
                  @plugs,
                  socket,
                  payload,
                  bindings,
                  __ENV__
                )

              case result do
                {:cont, socket, payload, bindings} ->
                  case @handler do
                    fun when is_function(fun) -> fun.(payload, bindings, socket)
                    {m, f, a} -> apply(m, f, [{payload, bindings}, socket])
                    module when is_atom(module) -> module.handle_in({payload, bindings}, socket)
                  end

                {:reply, reply, socket} ->
                  {:reply, reply, socket}

                {:noreply, socket} ->
                  {:noreply, socket}
              end
            end
        end
      end
    end
  end
end
