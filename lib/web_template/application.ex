defmodule WebTemplate.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      WebTemplateWeb.Telemetry,
      WebTemplate.Repo,
      {DNSCluster, query: Application.get_env(:web_template, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: WebTemplate.PubSub},
      {Inertia.SSR, path: Application.app_dir(:web_template, "priv")},
      # Start a worker by calling: WebTemplate.Worker.start_link(arg)
      # {WebTemplate.Worker, arg},
      # Start to serve requests, typically the last entry
      WebTemplateWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: WebTemplate.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    WebTemplateWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
