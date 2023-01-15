defmodule ChannelHandler do
  use Spark.Dsl,
    default_extensions: [extensions: ChannelHandler.Extension]

  alias ChannelHandler.Extension

  def get_handler(match_or_event) do
    case match_or_event.handler do
      {_, [fun: handler_fun]} -> handler_fun
      {module, _} -> module
    end
  end

  def process_plugs(plugs, socket, payload, bindings, env) do
    Enum.reduce_while(plugs, {:ok, socket, payload, bindings}, fn plug,
                                                                  {:ok, socket, payload, bindings} ->
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
        {:ok, socket, payload, bindings} -> {:cont, {:ok, socket, payload, bindings}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  def handle_before_compile(_opts) do
    quote location: :keep, generated: true do
      for match_or_event <- Spark.Dsl.Extension.get_entities(__MODULE__, [:handlers]) do
        handler = ChannelHandler.get_handler(match_or_event)
        plugs = match_or_event.plugs

        case match_or_event do
          %Extension.Match{prefix: prefix} ->
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
                Map.update(bindings, :__event, @prefix <> event, &(&1 <> @prefix <> event))

              result =
                ChannelHandler.process_plugs(
                  @plugs,
                  socket,
                  payload,
                  bindings,
                  __ENV__
                )

              case result do
                {:ok, socket, payload, bindings} ->
                  case @handler do
                    fun when is_function(fun) ->
                      fun.(event, {payload, bindings}, socket)

                    {m, f, a} ->
                      apply(m, f, [event, {payload, bindings}, socket])

                    module when is_atom(module) ->
                      module.handle_in(event, {payload, bindings}, socket)
                  end

                {:error, reason} ->
                  {:reply, {:error, reason}, socket}
              end
            end

          %Extension.Event{name: name} ->
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

              bindings = Map.put_new(bindings, :__event, @name)

              result =
                ChannelHandler.process_plugs(
                  @plugs,
                  socket,
                  payload,
                  bindings,
                  __ENV__
                )

              case result do
                {:ok, socket, payload, bindings} ->
                  case @handler do
                    fun when is_function(fun) -> fun.({payload, bindings}, socket)
                    {m, f, a} -> apply(m, f, [{payload, bindings}, socket])
                    module when is_atom(module) -> module.handle_in({payload, bindings}, socket)
                  end

                {:error, reason} ->
                  {:reply, {:error, reason}, socket}
              end
            end
        end
      end
    end
  end
end
