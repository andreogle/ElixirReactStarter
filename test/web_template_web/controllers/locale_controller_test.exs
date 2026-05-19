defmodule WebTemplateWeb.LocaleControllerTest do
  use WebTemplateWeb.ConnCase, async: true

  @moduletag :capture_log

  alias WebTemplate.Accounts

  describe "PUT /locale" do
    test "anonymous user: sets the locale cookie and redirects to the referer", %{conn: conn} do
      conn =
        conn
        |> put_req_header("referer", "http://www.example.com/login")
        |> put(~p"/locale", %{locale: "es"})

      assert redirected_to(conn) == "/login"
      assert conn.resp_cookies["locale"][:value] == "es"
    end

    test "anonymous user: cookie persists across requests via UserAuth fallback", %{conn: conn} do
      # First request: switch to Spanish.
      conn = put(conn, ~p"/locale", %{locale: "es"})
      assert conn.resp_cookies["locale"][:value] == "es"

      # Subsequent request reads the cookie back via fetch_current_user.
      # Phoenix.ConnTest carries Set-Cookie -> req_cookies across calls.
      next = get(conn, ~p"/")
      assert next.assigns.locale == "es"
    end

    @tag :authenticated
    test "authenticated user: writes user.locale AND sets cookie", %{conn: conn, user: user} do
      conn =
        conn
        |> put_req_header("referer", "http://www.example.com/dashboard")
        |> put(~p"/locale", %{locale: "es"})

      assert redirected_to(conn) == "/dashboard"
      assert conn.resp_cookies["locale"][:value] == "es"
      assert Accounts.get_user_by_email(user.email).locale == "es"
    end

    test "rejects an unsupported locale", %{conn: conn} do
      conn = put(conn, ~p"/locale", %{locale: "fr"})

      # action_fallback redirects to / for :bad_request
      assert redirected_to(conn) == ~p"/"
      refute conn.resp_cookies["locale"]
    end
  end
end
