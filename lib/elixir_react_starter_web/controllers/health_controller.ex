defmodule ElixirReactStarterWeb.HealthController do
  @moduledoc """
  Health endpoints for load balancers, Kubernetes, and uptime monitors.

    * `show/2` (`/health`) — **liveness**. Cheap by design: no DB, no
      external lookups, so a degraded dependency doesn't get the
      instance killed and restarted in a loop.
    * `ready/2` (`/health/ready`) — **readiness**. Confirms the DB pool
      can answer a trivial query before the instance is declared ready
      to take traffic. Returns 503 when it can't, so orchestrators hold
      traffic (rather than route it into errors) until the DB is up.
  """

  use ElixirReactStarterWeb, :controller

  alias Ecto.Adapters.SQL
  alias ElixirReactStarter.Repo

  require Logger

  def show(conn, _params) do
    json(conn, %{status: "ok"})
  end

  def ready(conn, _params) do
    case check_database() do
      :ok ->
        json(conn, %{status: "ok", database: "ok"})

      {:error, reason} ->
        Logger.error("Readiness check failed: database unreachable (#{inspect(reason)})")

        conn
        |> put_status(:service_unavailable)
        |> json(%{status: "error", database: "unreachable"})
    end
  end

  # A `SELECT 1` round-trips the connection pool without touching any
  # table. Any raise (pool checkout timeout, connection refused) becomes
  # an `{:error, _}` so a degraded DB reads as "not ready", never a 500.
  defp check_database do
    case SQL.query(Repo, "SELECT 1", []) do
      {:ok, _result} -> :ok
      {:error, reason} -> {:error, reason}
    end
  rescue
    error -> {:error, error}
  end
end
