# ChannelHandler

Helpers to organize and route messages in complex Phoenix channels.

## Installation

Add the following to your mix.exs dependencies:

```elixir
{:channel_handler, "~> 0.5.0"}
```

## Usage

After defining a channel with vanilla Phoenix's `channel`:

```elixir
channel "post:*", MyAppWeb.PostChannel
```

Define your channel handler, and add `use ChannelHandler.Router` in addition to the
`use MyAppWeb, :channel`:

```elixir
defmodule MyAppWeb.PostChannel do
  use MyAppWeb, :channel
  use ChannelHandler.Router
end
```

Now you can start defining matchers and event handlers:

```elixir
defmodule MyAppWeb.PostChannel do
  use MyAppWeb, :channel
  use ChannelHandler.Router

  join do
    handler fn _topic, _payload, socket ->
      {:ok, socket}
    end
  end

  router do
    plug MyAppWeb.ChannelPlugs.EnsureAuthenticated

    event "comments:create", MyAppWeb.PostCommentsHandler, :create

    delegate "comments:", MyAppWeb.PostCommentsHandler

    handle "post:create", fn payload, _bindings, socket ->
      case MyApp.Posts.create(payload) do
        {:ok, post} ->
          {:reply, {:ok, post}, socket}

        {:error, reason} ->
          {:reply, {:error, reason}, socket}
      end
    end

    scope "secret:" do
      plug &check_permission/4, :do_secret_stuff

      # An empty prefix matches anything
      delegate "", SuperSecretHandler
    end
  end

  def check_permission(socket, _payload, _bindings, permission) do
    if MyApp.Authorization.can?(socket.assigns.current_user, permission) do
      # using :cont resumes the event handling
      {:cont, socket, payload, bindings}
    else
      # returning :reply or :noreply halts the event handling
      {:reply, {:error, "Unauthorized"}, socket}
    end
  end
end

defmodule MyAppWeb.PostCommentsHandler do
  use ChannelHandler.Handler

  # Add a plug only for the create action
  plug MyAppWeb.ChannelPlugs.CheckPermission, :comment_posts when action: [:create]
  
  def handle_in(event, payload, bindings, socket) do
    # Do something with the delegated event
  end

  def create(payload, bindings, socket) do
    # Create a comment
  end
end
```

For more explanations about the API functions and what's possible, check the
docs for `ChannelHandler.Dsl`.

## Copyright and License
Copyright (c) 2023 dorgandash@gmail.com

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
