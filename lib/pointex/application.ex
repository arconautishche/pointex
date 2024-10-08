defmodule Pointex.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      PointexWeb.Telemetry,
      # Start the Ecto repository
      Pointex.Repo,
      # Start the PubSub system
      {Phoenix.PubSub, name: Pointex.PubSub},
      # Start Finch
      {Finch, name: Pointex.Finch},
      # Start the Endpoint (http/https)
      PointexWeb.Endpoint
    ]

    Logger.add_handlers(:pointex)

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Pointex.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PointexWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
