defmodule ElixirReactStarterWeb.PageControllerTest do
  use ElixirReactStarterWeb.ConnCase

  test "GET / renders the Home Inertia page", %{conn: conn} do
    conn = get(conn, ~p"/")
    body = html_response(conn, 200)
    assert body =~ ~s(&quot;component&quot;:&quot;Home&quot;)
  end
end
