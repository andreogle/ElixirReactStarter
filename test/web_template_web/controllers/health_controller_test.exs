defmodule WebTemplateWeb.HealthControllerTest do
  use WebTemplateWeb.ConnCase, async: true

  test "GET /health returns 200 with status payload", %{conn: conn} do
    conn = get(conn, ~p"/health")
    assert json_response(conn, 200) == %{"status" => "ok"}
  end
end
