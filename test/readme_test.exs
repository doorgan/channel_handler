defmodule ChannelHandlerTest.ReadmeTest do
  use ExUnit.Case, async: true

  alias ChannelHandlerTest.Support.Parser
  require Parser

  @project ChannelHandler.MixProject.project()

  readme_path = Parser.resource("README.md")
  readme = Parser.code_blocks(readme_path)

  @readme readme

  test "the version numbers match" do
    [_, version] = Regex.run(~r/\{:channel_handler, "~> (.*)"\}/, @readme |> hd |> elem(0))
    assert @project[:version] =~ version
  end

  @external_resource readme_path
end
