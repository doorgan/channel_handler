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
  Defines the `handle_in/3` functions for a Phoenix channel by matching
  on exact event names, or prefixes.
  """
  def handlers(), do: doc!([])

  @doc """
  When used in `join`, this is the function to run in the channel's `join`
  callback.
  """
  def handler(), do: doc!([])

  @doc """
  When used in `event` or `match`, this is the function that will be called to
  process the event. It's mostly equivalent to a
  `c:Phoehix.Channel.handle_in/3` with the following differences:

  - It takes an additional `bindings` argument, containing the values stored by
  previous plugs, for the current event. These are cleared after every event.
  - When used in `event`, the `event` argument is omitted as it is redundant.

  The handler function must return a reply/noreply tuple, just like a regular
  phoenix event handler.

  If a module or mfa tuple is provided, the corresponding `handle_in` function
  in that module will be called.

  Modules that `use ChannelHandler` can be used as well, as they define
  `handle_in` functions as well.
  """
  def handler(handler_fun), do: doc!([handler_fun])

  @doc """
  Registers a plug for the current `match` or `event`. Plugs are run in the
  order they are defined before the event handler.
  """
  def plug(plug), do: doc!([plug])

  @doc """
  Defines an event handler function for the given event name.

  If the module defining this is called by another event handler via `match`,
  the prefixes of previous handlers won't be included in the event name.

  For example, if module `A` defines `event "foo" do`, and module `B` matches
  `"app:"`, then the event `"app:foo"` will be matched by `B` and the handler
  for `"foo"` in `A` will be invoked.

  `plug/1` can be called inside `event/2`
  """
  def event(name, contents), do: doc!([name, contents])

  @doc """
  Defines a matcher function for the given event prefix. The prefix is a
  string literal that will be used to match the start of the event string.

  The event name without the prefix will be used when delegating to another
  handler module with `handler/1`.

  `plug/1` can be called inside `match/2`.
  """
  def match(prefix, contents), do: doc!([prefix, contents])
end
