defmodule ChannelHandler.Dsl do
  defmodule Group do
    defstruct [:prefix, :plugs, :handlers]
  end

  defmodule Delegate do
    defstruct [:prefix, :module]
  end

  defmodule Handle do
    defstruct [:name, :function]
  end

  defmodule Event do
    defstruct [:name, :module, :function]
  end

  defmodule Plug do
    defstruct [:plug, :options, :guards]
  end

  @plug %Spark.Dsl.Entity{
    name: :plug,
    target: Plug,
    args: [:plug, {:optional, :options, []}],
    schema: [
      plug: [
        type: {:or, [:atom, {:fun, 4}]},
        required: true
      ],
      options: [type: :any, required: false]
    ]
  }

  @event %Spark.Dsl.Entity{
    name: :event,
    target: Event,
    args: [:name, :module, :function],
    schema: [
      name: [type: :string, required: true],
      module: [type: :atom, required: true],
      function: [type: :atom, required: true]
    ]
  }

  @delegate %Spark.Dsl.Entity{
    name: :delegate,
    target: Delegate,
    args: [:prefix, :module],
    schema: [
      prefix: [type: :string, required: true],
      module: [type: :atom, required: true]
    ]
  }

  @handle %Spark.Dsl.Entity{
    name: :handle,
    target: Handle,
    args: [:name, :function],
    schema: [
      name: [type: :string, required: true],
      function: [type: {:fun, 3}, required: true]
    ]
  }

  @group %Spark.Dsl.Entity{
    name: :group,
    target: Group,
    args: [:prefix],
    entities: [plugs: [@plug], handlers: [@event, @delegate, @handle]],
    schema: [
      prefix: [type: :string, required: true]
    ]
  }

  @join %Spark.Dsl.Section{
    name: :join,
    schema: [
      channel: [
        type: :string,
        required: false,
        doc: """
        The channel path for this handler. By default this has no runtime effect,
        but can be used by plugs and handlers if necessary.

        The channel value is stored in the socket's `:__channel__` assign.
        """
      ],
      handler: [
        type: {:fun, 3},
        required: true,
        doc: """
        The function to run in the channel's `join` callback.
        """
      ]
    ]
  }

  @router %Spark.Dsl.Section{
    name: :router,
    describe: """
    Defines the `handle_in/3` functions for a Phoenix channel by matching
    on exact event names, or prefixes.
    """,
    entities: [
      @plug,
      @event,
      @delegate,
      @handle,
      @group
    ]
  }

  use Spark.Dsl.Extension,
    sections: [@join, @router]
end
