defmodule ElixirReactStarterWeb.PageControllerTest do
  use ElixirReactStarterWeb.ConnCase

  test "GET / renders the Home Inertia page", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200)
    assert inertia_component(conn) == "Home"
  end
end
