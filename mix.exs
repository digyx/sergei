defmodule Sergei.MixProject do
  use Mix.Project

  def project do
    [
      app: :sergei,
      version: "0.1.1",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [
        sergei: [
          include_executables_for: [:unix],
          steps: [:assemble, :tar]
        ]
      ]
    ]
  end

  def application do
    [
      mod: {Sergei.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:plug_cowboy, "~> 2.6.1"},
      {:nostrum, github: "Kraigie/nostrum"}
    ]
  end
end
