defmodule ChannelHandler.Context do
  @type t :: %__MODULE__{
          bindings: map,
          event: String.t()
        }
  defstruct [:bindings, :event]

  @doc """
  Puts a value in the context bindings.

  If the key is already present in the bindings, the value is overwritten.

  ## Examples

      iex> context = %Context{bindings: %{foo: 1}}
      iex> assign(context, :foo, 2)
      %Context{bindings: %{foo: 2}}
      iex> assign(context, :bar, 2)
      %Context{bindings: %{foo: 1, bar: 2}}
  """
  @spec assign(t, term, any) :: t
  def assign(context, key, value) do
    %{context | bindings: Map.put(context.bindings, key, value)}
  end

  @doc """
  Assigns a new value to the context bindings.

  If the key is already present in the bindings, the context is returned.

  ## Examples

      iex> context = %Context{bindings: %{foo: 1}}
      iex> assign_new(context, :foo, fn -> 2 end)
      %Context{bindings: %{foo: 1}}
      iex> assign_new(context, :bar, fn -> 2 end)
      %Context{bindings: %{foo: 1, bar: 2}}
  """
  @spec assign_new(t, term, (map -> any) | (() -> any)) :: t
  def assign_new(context, key, generator)

  def assign_new(%{bindings: bindings} = context, key, _) when is_map_key(bindings, key) do
    context
  end

  def assign_new(%{bindings: bindings} = context, key, generator)
      when is_function(generator, 0) do
    %{context | bindings: Map.put(bindings, key, generator.())}
  end

  def assign_new(%{bindings: bindings} = context, key, generator)
      when is_function(generator, 1) do
    %{context | bindings: Map.put(bindings, key, generator.(bindings))}
  end
end
