defmodule WebTemplateWeb.Plugs.DocsIndexRedirectTest do
  use WebTemplateWeb.ConnCase, async: true

  alias WebTemplateWeb.Plugs.DocsIndexRedirect

  defp call(conn, path_info) do
    DocsIndexRedirect.call(%{conn | path_info: path_info}, DocsIndexRedirect.init([]))
  end

  test "redirects /dev/docs to the index page", %{conn: conn} do
    conn = call(conn, ["dev", "docs"])

    assert conn.halted
    assert conn.status == 302
    assert get_resp_header(conn, "location") == ["/dev/docs/index.html"]
  end

  test "redirects the trailing-slash form /dev/docs/ as well", %{conn: conn} do
    conn = call(conn, ["dev", "docs", ""])

    assert conn.halted
    assert get_resp_header(conn, "location") == ["/dev/docs/index.html"]
  end

  test "passes other paths through untouched", %{conn: conn} do
    conn = call(conn, ["dev", "docs", "index.html"])

    refute conn.halted
    assert conn.status == nil
  end
end
