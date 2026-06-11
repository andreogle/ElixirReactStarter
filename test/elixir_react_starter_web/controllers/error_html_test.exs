defmodule ElixirReactStarterWeb.ErrorHTMLTest do
  use ElixirReactStarterWeb.ConnCase, async: true

  # Bring render_to_string/4 for testing custom views
  import Phoenix.Template, only: [render_to_string: 4]

  test "renders a branded 404 page" do
    html = render_to_string(ElixirReactStarterWeb.ErrorHTML, "404", "html", [])
    assert html =~ "Page not found"
    assert html =~ "404"
    # Self-contained: no external script that could also be down.
    refute html =~ "<script"
  end

  test "renders a branded 500 page" do
    html = render_to_string(ElixirReactStarterWeb.ErrorHTML, "500", "html", [])
    assert html =~ "Something went wrong"
    assert html =~ "500"
    refute html =~ "<script"
  end

  test "falls back to the plain status message for templates without a page" do
    assert render_to_string(ElixirReactStarterWeb.ErrorHTML, "401", "html", []) == "Unauthorized"
  end
end
