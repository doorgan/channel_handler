defmodule ChannelHandler.Handler do
  @moduledoc """
  A module implementing an event handler.

  You can `use ChannelHandler.Handler` to import phoenix functions like `push`
  or reply, and the `plug` macro for handler-level plugs.
  """

  @doc """
  Hanndles a delegated event.

  This function is called when using `delegate` in a router.

      defmodule MyRouter do
        use ChannelHandler.Router

        delegate "posts:", PostsHandler
      end

      defmodule PostsHandler do
        use ChannelHandler.Handler

        def handle_in("create", payload, context, socket) do
          # ...
        end
      end
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
  Registers a plug for the current module.

      defmodule MyHandler do
        use ChannelHandler.Handler

        plug &check_permissions/4, [:create]

        def create(_payload, context, socket) do
          # Authorized users only
        end

        def check_permissions(socket, payload, context, opts) do
          permissions = opts[:permissions] || []
          user_permissions = socket.assigns.current_user.permissions

          if Enum.any?(permissions, &Enum.member?(user_permissions, &1)) do
            {:cont, socket, payload, context}
          else
            {:reply, {:error, "Unauthorized"}, socket}
          end
        end
      end

  Plugs support guards, and can be used to filter events or actions.

      plug &do_something/4 when action in [:create, :update]

  Due to operator precedence in Elixir, if the second argument is a keyword
  list, we need to wrap the keyword in `[...]` when using `when`:

      plug &authenticate/4, [usernames:  ["jose", "eric", "sonny"]] when action in [:create, :update]
      plug &authenticate/4, [usernames: ["admin"]] when not action in [:create]

  The first plug will run when the action is `:create` or `:update`. The second
  will always run except when the action is `:create`.

  Those guards work like regular Elixir guards and the only variables accessible
  in the guard are the action as an atom and the event as a string.
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

  @doc """
  Defines a module plug.

  For more information about plugs, check `plug/1`.
  """
  defmacro plug(plug, opts) do
    plug(plug, opts, [], __CALLER__)
  end

  defp plug(plug, opts, guards, env) do
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
