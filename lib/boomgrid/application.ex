defmodule Boom.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      BoomWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Boom.PubSub},
      Boom.Presence,
      # Start the Endpoint (http/https)
      BoomWeb.Endpoint,
      {Registry, keys: :unique, name: Boom.GameRegistry},
      {DynamicSupervisor, strategy: :one_for_one, name: Boom.GameSupervisor}
      # Start a worker by calling: Boom.Worker.start_link(arg)
      # {Boom.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Boom.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    BoomWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
