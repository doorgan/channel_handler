# ChannelHandler

Helpers to organize and route messages in complex Phoenix channels.

## Installation

Add the following to your mix.exs dependencies:

```elixir
{:channel_handler, "~> 0.1.0"}
```

## Usage

After defining a channel with vanilla Phoenix's `channel`:

```elixir
channel "post:*", MyAppWeb.PostChannel
```

Define your channel handler, and add `use ChannelHandler` in addition to the
`use MyAppWeb, :channel`:

```elixir
defmodule MyAppWeb.PostChannel do
  use MyAppWeb, :channel
  use ChannelHandler
end
```

Now you can start defining matchers and event handlers:
```elixir
defmodule MyAppWeb.PostChannel do
  use MyAppWeb, :channel
  use ChannelHandler

  join do
    handler fn _topic, _payload, socket ->
      {:ok, socket}
    end
  end

  handlers do
    match "comments:" do
      handler MyAppWeb.PostCommentsHandler
    end

    event "post:create" do
      plug &check_permission/4, :create_post

      handler fn payload, _bindings, socket
        case MyApp.Posts.create(payload) do
          {:ok, post} ->
            {:reply, {:ok, post}, socket}

          {:error, reason} ->
            {:reply, {:error, reason}, socket}
        end
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
end

defmodule MyAppWeb.PostCommentsHandler do
  use ChannelHandler

  handlers do
    event "create" do
      handler fn payload, _bindings, socket do
        # Create a comment
      end
    end
  end
end
```

For more explanations about the API functions and what's possible, check the
docs for `ChannelHandler.API`.

## Copyright and License
Copyright (c) 2021 dorgandash@gmail.com

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.