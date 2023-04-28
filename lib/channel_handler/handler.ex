defmodule ChannelHandler.Handler do
  @moduledoc """
  A module implementing an event handler.

  You can `use ChannelHandler.Handler` to import phoenix functions like `push`
  or reply, and the `plug` macro for handler-level plugs.
  """

  @callback handle_in(String.t(), term, map, Phoenix.Socket.t()) :: Phoenix.Channel.reply()

  defmacro __using__(_opts) do
    quote do
      Module.register_attribute(__MODULE__, :plugs, accumulate: true, persist: true)

      import ChannelHandler.Handler, only: [plug: 1, plug: 2]
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

    plug_fun =
      quote do
        fn socket, payload, context, opts ->
          unquote(Macro.var(:action, nil)) = context.action
          unquote(Macro.var(:event, nil)) = context.event

          # Avoid "variable not used" warnings
          _ = var!(action)
          _ = var!(event)

          case true do
            true when unquote(guards) ->
              case unquote(expanded_value) do
                module when is_atom(module) ->
                  module.call(socket, payload, context, opts)

                function when is_function(function, 4) ->
                  function.(socket, payload, context, opts)
              end

            true ->
              {:cont, socket, payload, context}
          end
        end
      end

    quote location: :keep do
      unquote(function)

      @plugs %ChannelHandler.Dsl.Plug{
        plug: unquote(plug_fun),
        options: unquote(opts)
      }
    end
  end

  defp expand_alias({:__aliases__, _, _} = alias, env),
    do: Macro.expand(alias, %{env | function: {:__attr__, 3}})

  defp expand_alias(other, _env), do: other
end
