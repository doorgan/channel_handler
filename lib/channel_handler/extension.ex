defmodule ChannelHandler.Extension do
  defmodule Plug do
    defstruct [:function]
  end

  defmodule Event do
    defstruct [:name, :handler, :plugs, :payload]
  end

  defmodule Match do
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
       {ChannelHandler.Plugs.Handler.Function, 3}},
    required: true
  ]

  @event_handler [
    type:
      {:spark_function_behaviour, ChannelHandler.Plugs.Handler,
       {ChannelHandler.Plugs.Handler.Function, 2}},
    required: true
  ]

  @event %Spark.Dsl.Entity{
    name: :event,
    target: Event,
    args: [:name],
    describe: """
    Matches the `name` evemt and delegates it to a handler module or function.

    ## Examples

        match "posts:" do
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
    """,
    target: Match,
    args: [:prefix],
    entities: [plugs: [@plug]],
    schema: [
      prefix: [
        type: :string,
        required: true
      ],
      handler: @match_handler
    ]
  }

  @join %Spark.Dsl.Section{
    name: :join,
    schema: [
      channel: [
        type: :string,
        required: true
      ],
      handler: [
        type: {:fun, 3},
        required: true
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
