defmodule ChannelHandler.MixProject do
  use Mix.Project

  def project do
    [
      app: :channel_handler,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
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
      {:phoenix, "~> 1.6.15"},
      {:spark, github: "ash-project/spark", branch: "main"}
    ]
  end
end
