defmodule ChannelHandler.API do
  @moduledoc """
  Lists all functions allowed in the ChannelHandler API.

  Note the functions in this module exist for documentation purposes and one
  should never need to invoke them directly.
  """

  @dialyzer :no_return

  defp doc!(_) do
    raise "the functions in ChannelHandler.API should not be invoked directly, " <>
            "they serve for documentation purposes only"
  end

  @doc """
  The channel path for this handler. By default this has no runtime effect,
  but can be used by plugs and handlers if necessary.

  The channel value is stored in the socket's `:__channel__` assign.
  """
  def join(), do: doc!([])

  @doc """
  Defines the `handle_in/3` functions for a Phoenix channel by matching on exact
  event names, or prefixes.

  ## Example

      router do
        # Adds a module plug to the list of plugs to be run before each event
        plug MyApp.ChannelPlugs.EnsureAuthenticated

        # Delegate all events starting with `"foo:"` to the `FooHandler` module
        delegate "foo:", FooHandler

        # Delegates `"create"` events to the `FooHandler.create/3` function
        event "create", FooHandler, :create

        # Defines an inline handler
        handle "delete", fn payload, context, socket ->
          result delete_post(payload)

          {:reply, result, socket}
        end

        # Defines a group, which is useful to add plugs for a specific group of
        # events
        group "comments:" do
          # Adds a capture function as a plug to be run before each event in the
          group
          plug &check_permission/4, :comment

          event "create", CommentsHandler, :create
        end
      end
  """
  def router(), do: doc!([])

  @doc """
  Defines a handler for the `event`. `function` must be an arity 3 function
  taking the payload, context and socket.any()

  ## Example

      router do
        handle "create", fn payload, _context, socket ->
          post = create_post(payload)

          {:reply, post}
        end
      end
  """
  def handle(event, function), do: doc!([event, function])

  @doc """
  Registers a plug for the current router/group. Plugs are run in the
  order they are defined before the event handler.

  An optional argument can be passed as the options for the plug.
  """
  def plug(plug, opts \\ []), do: doc!([plug, opts])
end
