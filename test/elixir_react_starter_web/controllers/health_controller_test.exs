defmodule ElixirReactStarterWeb.HealthControllerTest do
  use ElixirReactStarterWeb.ConnCase, async: true

  test "GET /health returns 200 with status payload", %{conn: conn} do
    conn = get(conn, ~p"/health")
    assert json_response(conn, 200) == %{"status" => "ok"}
  end

  test "GET /health/ready returns 200 when the database is reachable", %{conn: conn} do
    conn = get(conn, ~p"/health/ready")
    assert json_response(conn, 200) == %{"status" => "ok", "database" => "ok"}
  end
end
