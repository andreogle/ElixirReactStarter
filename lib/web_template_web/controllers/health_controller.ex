defmodule WebTemplateWeb.HealthController do
  @moduledoc """
  Liveness endpoint. Load balancers, Kubernetes, and uptime monitors
  poll this to decide whether the app is up. Keep it cheap — no
  database calls, no external lookups — so a degraded dependency
  doesn't take the instance out of the pool.
  """

  use WebTemplateWeb, :controller

  def show(conn, _params) do
    render(conn, :show)
  end
end
