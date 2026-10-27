defmodule ElixirReactStarterWeb.PageControllerTest do
  use ElixirReactStarterWeb.ConnCase

  test "GET / renders the Home Inertia page", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200)
    assert inertia_component(conn) == "Home"
  end

  test "without SSR the page data uses the v3 script tag with the CSP nonce", %{conn: conn} do
    conn = get(conn, ~p"/")
    html = html_response(conn, 200)

    assert html =~ ~s(<div id="app"></div>)
    refute html =~ "data-server-rendered"

    [_, attributes, json] =
      Regex.run(~r/<script([^>]*data-page="app"[^>]*)>(.*?)<\/script>/s, html)

    assert attributes =~ ~s(type="application/json")
    assert attributes =~ ~s(nonce="#{conn.assigns.csp_nonce}")
    assert Jason.decode!(json)["component"] == "Home"
  end
end
