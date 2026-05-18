defmodule WebTemplateWeb.UserAuthTest do
  use WebTemplateWeb.ConnCase, async: true

  alias WebTemplate.Accounts
  alias WebTemplateWeb.UserAuth

  @session_key "user_token"
  @return_to_key "user_return_to"

  setup %{conn: conn} do
    user = :user |> build() |> confirmed() |> insert()

    conn =
      conn
      |> Map.replace!(:secret_key_base, WebTemplateWeb.Endpoint.config(:secret_key_base))
      |> init_test_session(%{})

    %{conn: conn, user: user}
  end

  describe "fetch_current_user/2" do
    test "assigns current_user when the session token is valid", %{conn: conn, user: user} do
      token = Accounts.generate_user_session_token(user)
      conn = conn |> put_session(@session_key, token) |> UserAuth.fetch_current_user([])

      assert conn.assigns.current_user.id == user.id
    end

    test "assigns nil when no token is present", %{conn: conn} do
      conn = UserAuth.fetch_current_user(conn, [])
      assert conn.assigns.current_user == nil
    end

    test "assigns nil for a token that doesn't match any session", %{conn: conn} do
      conn =
        conn
        |> put_session(@session_key, :crypto.strong_rand_bytes(32))
        |> UserAuth.fetch_current_user([])

      assert conn.assigns.current_user == nil
    end

    test "assigns the request locale from Accept-Language", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept-language", "es-ES,es;q=0.9,en;q=0.5")
        |> UserAuth.fetch_current_user([])

      assert conn.assigns.locale == "es"
    end

    test "falls back to the default locale without Accept-Language", %{conn: conn} do
      conn = UserAuth.fetch_current_user(conn, [])
      assert conn.assigns.locale == "en"
    end
  end

  describe "require_authenticated_user/2" do
    test "passes through when current_user is assigned", %{conn: conn, user: user} do
      conn = conn |> assign(:current_user, user) |> UserAuth.require_authenticated_user([])
      refute conn.halted
    end

    test "redirects to /login and stores return_to for GET", %{conn: conn} do
      conn =
        :get
        |> Plug.Test.conn("/some/page")
        |> Map.put(:secret_key_base, conn.secret_key_base)
        |> Plug.Session.call(
          Plug.Session.init(store: :cookie, key: "_test", signing_salt: "test")
        )
        |> fetch_session()
        |> Phoenix.Controller.fetch_flash()
        |> UserAuth.require_authenticated_user([])

      assert conn.halted
      assert redirected_to(conn) == ~p"/login"
      assert get_session(conn, @return_to_key) == "/some/page"
    end

    test "does not store return_to for non-GET requests", %{conn: conn} do
      conn =
        :post
        |> Plug.Test.conn("/some/page")
        |> Map.put(:secret_key_base, conn.secret_key_base)
        |> Plug.Session.call(
          Plug.Session.init(store: :cookie, key: "_test", signing_salt: "test")
        )
        |> fetch_session()
        |> Phoenix.Controller.fetch_flash()
        |> UserAuth.require_authenticated_user([])

      assert conn.halted
      assert redirected_to(conn) == ~p"/login"
      assert get_session(conn, @return_to_key) == nil
    end
  end

  describe "redirect_if_user_is_authenticated/2" do
    test "redirects to / when current_user is set", %{conn: conn, user: user} do
      conn = conn |> assign(:current_user, user) |> UserAuth.redirect_if_user_is_authenticated([])
      assert conn.halted
      assert redirected_to(conn) == ~p"/"
    end

    test "passes through when current_user is nil", %{conn: conn} do
      conn = conn |> assign(:current_user, nil) |> UserAuth.redirect_if_user_is_authenticated([])
      refute conn.halted
    end
  end

  describe "log_in_user/2" do
    test "writes a session token and redirects to /", %{conn: conn, user: user} do
      conn = UserAuth.log_in_user(conn, user)

      assert redirected_to(conn) == ~p"/"
      assert get_session(conn, @session_key)
    end

    test "redirects to user_return_to when set", %{conn: conn, user: user} do
      conn = conn |> put_session(@return_to_key, "/somewhere") |> UserAuth.log_in_user(user)

      assert redirected_to(conn) == "/somewhere"
    end
  end

  describe "log_out_user/1" do
    test "deletes the session token and clears the session", %{conn: conn, user: user} do
      token = Accounts.generate_user_session_token(user)
      conn = conn |> put_session(@session_key, token) |> UserAuth.log_out_user()

      assert redirected_to(conn) == ~p"/"
      assert get_session(conn, @session_key) == nil
      refute Accounts.get_user_by_session_token(token)
    end
  end
end
