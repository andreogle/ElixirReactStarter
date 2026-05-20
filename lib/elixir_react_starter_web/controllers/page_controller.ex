defmodule ElixirReactStarterWeb.PageController do
  use ElixirReactStarterWeb, :controller

  def home(conn, _params) do
    render_inertia(conn, "Home")
  end
end
