defmodule Dingleberry.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Initialize LLM classification cache (ETS table)
    Dingleberry.LLM.Classifier.init_cache()

    children = [
      DingleberryWeb.Telemetry,
      Dingleberry.Repo,
      {Ecto.Migrator,
       repos: Application.fetch_env!(:dingleberry, :ecto_repos), skip: skip_migrations?()},
      {DNSCluster, query: Application.get_env(:dingleberry, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Dingleberry.PubSub},
      # Registry for MCP proxy sessions
      {Registry, keys: :unique, name: Dingleberry.ProxyRegistry},
      # Jido Signal Bus (middleware pipeline: risk classifier -> audit logger -> logger)
      Dingleberry.Signals.BusConfig.child_spec(),
      # Core Dingleberry services
      Dingleberry.Policy.Engine,
      Dingleberry.Approval.Queue,
      Dingleberry.Shell.Interceptor,
      # Start to serve requests, typically the last entry
      DingleberryWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Dingleberry.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    DingleberryWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp skip_migrations?() do
    # By default, sqlite migrations are run when using a release
    System.get_env("RELEASE_NAME") == nil
  end
end
