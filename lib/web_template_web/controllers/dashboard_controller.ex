defmodule WebTemplateWeb.DashboardController do
  @moduledoc """
  Post-login landing. Wraps the Dashboard Inertia page; any data the
  dashboard cards need can be loaded here and passed via `assign_prop`.
  """

  use WebTemplateWeb, :controller

  def show(conn, _params) do
    render_inertia(conn, "Dashboard")
  end
end
