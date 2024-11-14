defmodule ChannelHandler.MixProject do
  use Mix.Project

  @repo_url "https://github.com/doorgan/channel_handler"
  @version "0.6.2"

  def project do
    [
      app: :channel_handler,
      version: @version,
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev},
      {:phoenix, ">= 1.6.0", optional: true, only: :test},
      {:spark, "~> 2.2.0"}
    ]
  end

  defp package do
    [
      description: "Utilities to organize Phoenix channels.",
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @repo_url
      }
    ]
  end

  defp docs do
    [
      extras: [
        LICENSE: [title: "License"],
        "README.md": [title: "Overview"]
      ],
      main: "readme",
      homepage_url: @repo_url,
      source_ref: "v#{@version}",
      source_url: @repo_url,
      formatters: ["html"]
    ]
  end
end
