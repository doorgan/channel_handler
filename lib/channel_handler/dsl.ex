defmodule ChannelHandler.Dsl do
  @moduledoc false

  defmodule Plug do
    @moduledoc false
    defstruct [:function]
  end

  defmodule Event do
    @moduledoc false
    defstruct [:name, :handler, :plugs, :payload]
  end

  defmodule Match do
    @moduledoc false
    defstruct [:prefix, :handler, :plugs]
  end

  @plug %Spark.Dsl.Entity{
    name: :plug,
    target: Plug,
    args: [:function],
    schema: [
      function: [
        type:
          {:spark_function_behaviour, ChannelHandler.Plugs.Plug,
           {ChannelHandler.Plugs.Plug.Function, 4}},
        required: true
      ]
    ]
  }

  @match_handler [
    type:
      {:spark_function_behaviour, ChannelHandler.Plugs.Handler,
       {ChannelHandler.Plugs.Handler.Function, 4}},
    required: true
  ]

  @event_handler [
    type:
      {:spark_function_behaviour, ChannelHandler.Plugs.Handler,
       {ChannelHandler.Plugs.Handler.Function, 3}},
    required: true
  ]

  @event %Spark.Dsl.Entity{
    name: :event,
    target: Event,
    args: [:name],
    describe: """
    Matches the `name` event and delegates it to a handler module or function.

    It allows specifying the plugs that will run before the handler.

    ## Examples

        event "create_post" do
          plug &ensure_authenticated/4

          handler MyAppWeb.Channels.PostsHandler
        end
    """,
    entities: [plugs: [@plug]],
    schema: [
      name: [
        type: :string,
        required: true,
        doc: """
        The event to match.
        """
      ],
      handler: @event_handler
    ]
  }

  @match %Spark.Dsl.Entity{
    name: :match,
    describe: """
    Matches an event starting with `prefix` and delegates it to a handler module
    or function.

    It allows specifying the plugs that will run before the handler.

    ## Examples

        match "posts:" do
          plug &ensure_authenticated/4

          handler MyAppWeb.Channels.PostsHandler
        end
    """,
    target: Match,
    args: [:prefix],
    entities: [plugs: [@plug]],
    schema: [
      prefix: [
        type: :string,
        required: true,
        doc: """
        The event prefix to match. If you want to match any event, you can use
        `""` as the prefix.
        """
      ],
      handler: @match_handler
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

  @handlers %Spark.Dsl.Section{
    name: :handlers,
    describe: """
    Defines the `handle_in/3` functions for a Phoenix channel by matching
    on exact event names, or prefixes.
    """,
    entities: [@event, @match]
  }

  use Spark.Dsl.Extension,
    sections: [@join, @handlers]
end
