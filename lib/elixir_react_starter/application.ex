defmodule ElixirReactStarter.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ElixirReactStarterWeb.Telemetry,
      ElixirReactStarter.Repo,
      {DNSCluster,
       query: Application.get_env(:elixir_react_starter, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: ElixirReactStarter.PubSub},
      # Rate-limit counters (auth throttling). Periodic cleanup keeps the
      # ETS table from growing unbounded.
      {ElixirReactStarter.RateLimit, [clean_period: :timer.minutes(10)]},
      {Inertia.SSR, path: Application.app_dir(:elixir_react_starter, "priv")},
      # Background jobs. Config (queues, plugins) lives under the `Oban`
      # key in config/config.exs; tests run it in `:manual` mode. Starts
      # after the Repo so its tables are reachable.
      {Oban, Application.fetch_env!(:elixir_react_starter, Oban)},
      # Start to serve requests, typically the last entry
      ElixirReactStarterWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ElixirReactStarter.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ElixirReactStarterWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
