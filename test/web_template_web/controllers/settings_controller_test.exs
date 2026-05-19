defmodule WebTemplateWeb.SettingsControllerTest do
  use WebTemplateWeb.ConnCase, async: true

  # The failure-path tests (wrong password, etc.) intentionally emit
  # Logger.warning. Capture them — ExUnit still attaches captured
  # output to any failing test for debugging.
  @moduletag :capture_log

  alias WebTemplate.Accounts

  describe "GET /settings" do
    @tag :authenticated
    test "renders the Settings Inertia page", %{conn: conn} do
      conn = get(conn, ~p"/settings")
      assert html_response(conn, 200) =~ ~s(&quot;component&quot;:&quot;Settings&quot;)
    end

    test "redirects to /login when not authenticated", %{conn: conn} do
      conn = get(conn, ~p"/settings")
      assert redirected_to(conn) == ~p"/login"
    end
  end

  describe "PUT /settings/password" do
    @tag :authenticated
    test "updates the password and keeps the current browser logged in", %{conn: conn, user: user} do
      conn =
        put(conn, ~p"/settings/password", %{
          current_password: "valid_password123",
          password: "brand_new_pw"
        })

      assert redirected_to(conn) == ~p"/settings"
      # Browser stays logged in (new session token issued).
      assert get_session(conn, "user_token")
      # New password works.
      assert Accounts.get_user_by_email_and_password(user.email, "brand_new_pw")
    end

    @tag :authenticated
    test "rejects an incorrect current password", %{conn: conn, user: user} do
      conn =
        put(conn, ~p"/settings/password", %{
          current_password: "wrong",
          password: "brand_new_pw"
        })

      assert redirected_to(conn) == ~p"/settings"
      # Old password still works (no change happened).
      assert Accounts.get_user_by_email_and_password(user.email, "valid_password123")
    end

    @tag :authenticated
    test "rejects a short new password", %{conn: conn, user: user} do
      conn =
        put(conn, ~p"/settings/password", %{
          current_password: "valid_password123",
          password: "short"
        })

      assert redirected_to(conn) == ~p"/settings"
      assert Accounts.get_user_by_email_and_password(user.email, "valid_password123")
    end
  end

  describe "DELETE /settings/account" do
    @tag :authenticated
    test "deletes the user and clears the session", %{conn: conn, user: user} do
      conn = delete(conn, ~p"/settings/account", %{password: "valid_password123"})

      assert redirected_to(conn) == ~p"/"
      assert get_session(conn, "user_token") == nil
      refute Accounts.get_user_by_email(user.email)
    end

    @tag :authenticated
    test "rejects an incorrect password", %{conn: conn, user: user} do
      conn = delete(conn, ~p"/settings/account", %{password: "wrong"})

      assert redirected_to(conn) == ~p"/settings"
      assert get_session(conn, "user_token")
      assert Accounts.get_user_by_email(user.email)
    end
  end
end
