defmodule ElixirReactStarter.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias ElixirReactStarter.Ecto.UUIDv7

  @impl true
  def start(_type, _args) do
    # Attach the Sentry :logger handler configured under `config
    # :elixir_react_starter, :logger`. Routes OTP crash reports (Bandit
    # request crashes, Oban job failures, GenServer crashes) to Sentry.
    # Inert until a DSN is set, so this is a no-op in dev/test. The handler
    # config is static (config/config.exs), so this always returns :ok;
    # matching it documents that and fails loudly on a genuine misconfig.
    :ok = Logger.add_handlers(:elixir_react_starter)

    # Initialize the monotonic UUID v7 counter before any process can mint an
    # id, so primary keys are strictly ordered from the very first insert.
    UUIDv7.init()

    # The server-rendering workers are Node processes and inherit this
    # environment. Without NODE_ENV=production the `nodejs` package loads
    # the SSR bundle again on every render and a worker runs out of heap
    # after a few hundred renders. Development sets it here, and
    # `ElixirReactStarterWeb.SSRReloader` picks up rebuilt bundles.
    if Application.get_env(:elixir_react_starter, :reload_ssr),
      do: System.put_env("NODE_ENV", "production")

    children = [
      ElixirReactStarterWeb.Telemetry,
      ElixirReactStarter.Repo,
      {DNSCluster,
       query: Application.get_env(:elixir_react_starter, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: ElixirReactStarter.PubSub},
      # Rate-limit counters (auth throttling). Periodic cleanup keeps the
      # ETS table from growing unbounded.
      {ElixirReactStarter.RateLimit, [clean_period: :timer.minutes(10)]},
      {Inertia.SSR,
       path: Application.app_dir(:elixir_react_starter, "priv"), pool_size: ssr_pool_size()},
      ssr_reloader(),
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
    Supervisor.start_link(List.flatten(children), opts)
  end

  # Development restarts the SSR workers when their bundle is rebuilt.
  defp ssr_reloader do
    if Application.get_env(:elixir_react_starter, :reload_ssr) do
      [
        {ElixirReactStarterWeb.SSRReloader,
         path: Application.app_dir(:elixir_react_starter, "priv/ssr.js")}
      ]
    else
      []
    end
  end

  # Number of Node.js workers in the Inertia SSR pool. Each worker loads the
  # SSR bundle and holds its own V8 heap, so this is the main memory lever on
  # the Node side. Defaults low (2); raise SSR_POOL_SIZE on bigger instances
  # that need more concurrent server renders.
  defp ssr_pool_size do
    case System.get_env("SSR_POOL_SIZE") do
      nil -> 2
      value -> String.to_integer(value)
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ElixirReactStarterWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
