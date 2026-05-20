defmodule ElixirReactStarterWeb.FallbackControllerTest do
  use ElixirReactStarterWeb.ConnCase, async: true

  alias ElixirReactStarter.Accounts.User
  alias ElixirReactStarterWeb.FallbackController

  setup %{conn: conn} do
    # assign_errors + put_flash both read/write through the session, and
    # put_flash additionally requires the flash to be fetched first.
    conn = conn |> init_test_session(%{}) |> Phoenix.Controller.fetch_flash([])
    %{conn: conn}
  end

  describe "call/2 with a changeset error" do
    test "redirects to the referer path with errors assigned", %{conn: conn} do
      changeset = User.registration_changeset(%User{}, %{})

      conn =
        conn
        |> put_req_header("referer", "http://localhost/register")
        |> FallbackController.call({:error, changeset})

      assert redirected_to(conn) == "/register"
    end

    test "falls back to / when there is no referer", %{conn: conn} do
      changeset = User.registration_changeset(%User{}, %{})
      conn = FallbackController.call(conn, {:error, changeset})
      assert redirected_to(conn) == "/"
    end

    test "ignores a referer with no usable path", %{conn: conn} do
      changeset = User.registration_changeset(%User{}, %{})

      conn =
        conn
        |> put_req_header("referer", "mailto:nobody@example.com")
        |> FallbackController.call({:error, changeset})

      assert redirected_to(conn) == "/"
    end
  end

  describe "call/2 with other error shapes" do
    test ":not_found renders the 404 page", %{conn: conn} do
      conn = FallbackController.call(conn, {:error, :not_found})
      assert conn.status == 404
    end

    test ":unauthorized redirects to /login with an error flash", %{conn: conn} do
      conn = FallbackController.call(conn, {:error, :unauthorized})
      assert redirected_to(conn) == "/login"
      assert Phoenix.Flash.get(conn.assigns.flash, :error)
    end

    test ":bad_request redirects to / with an error flash", %{conn: conn} do
      conn = FallbackController.call(conn, {:error, :bad_request})
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error)
    end

    test "{:bad_request, message} redirects to / with the given message", %{conn: conn} do
      conn = FallbackController.call(conn, {:error, {:bad_request, "Something specific"}})
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Something specific"
    end
  end
end
