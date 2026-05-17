defmodule WebTemplateWeb.PageController do
  use WebTemplateWeb, :controller

  def home(conn, _params) do
    render_inertia(conn, "Home")
  end
end
