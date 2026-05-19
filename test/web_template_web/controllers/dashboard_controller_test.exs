defmodule WebTemplateWeb.DashboardControllerTest do
  use WebTemplateWeb.ConnCase, async: true

  describe "GET /dashboard" do
    @tag :authenticated
    test "renders the Dashboard Inertia page", %{conn: conn} do
      conn = get(conn, ~p"/dashboard")
      assert html_response(conn, 200) =~ ~s(&quot;component&quot;:&quot;Dashboard&quot;)
    end

    test "redirects to /login when not authenticated", %{conn: conn} do
      conn = get(conn, ~p"/dashboard")
      assert redirected_to(conn) == ~p"/login"
    end
  end
end
