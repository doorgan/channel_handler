defmodule ChannelHandler.Context do
  @type t :: %__MODULE__{
          bindings: map,
          event: String.t()
        }
  defstruct [:bindings, :event]
end
