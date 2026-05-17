defmodule WebTemplateWeb.PageController do
  use WebTemplateWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
