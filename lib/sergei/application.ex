defmodule Sergei.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Consumer
      Sergei.Consumer,
      Sergei.Player,
      Sergei.VoiceStateCache,
      {Plug.Cowboy, scheme: :http, plug: Server, options: [port: 8080]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [
      strategy: :one_for_one,
      name: Sergei.Supervisor
    ]

    Supervisor.start_link(children, opts)
  end
end
