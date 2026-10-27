defmodule ElixirReactStarterWeb.PartialReloadTest do
  use ElixirReactStarterWeb.ConnCase, async: true

  import Inertia.Controller, only: [assign_prop: 3]

  setup %{conn: conn} do
    version = get(conn, ~p"/").private.inertia_version
    # A callback notification catches work that runs even when its result is
    # discarded from the response (the regression in adapter 3.0.1).
    caller = self()
    ref = make_ref()

    conn =
      conn
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", version)
      |> assign_prop(:expensive, fn ->
        send(caller, ref)
        "loaded"
      end)

    %{conn: conn, loaded: ref}
  end

  test "a full visit evaluates lazy props once", %{conn: conn, loaded: ref} do
    conn = get(conn, ~p"/")

    assert json_response(conn, 200)["props"]["expensive"] == "loaded"
    assert_received ^ref
    refute_received ^ref
  end

  for {header, value} <- [
        {"x-inertia-partial-data", "errors"},
        {"x-inertia-partial-except", "expensive"}
      ] do
    test "#{header} skips excluded callbacks", %{conn: conn, loaded: ref} do
      conn =
        conn
        |> put_req_header("x-inertia-partial-component", "Home")
        |> put_req_header(unquote(header), unquote(value))
        |> get(~p"/")

      refute Map.has_key?(json_response(conn, 200)["props"], "expensive")
      refute_received ^ref
    end
  end

  test "a partial reload evaluates a requested lazy prop once", %{conn: conn, loaded: ref} do
    conn =
      conn
      |> put_req_header("x-inertia-partial-component", "Home")
      |> put_req_header("x-inertia-partial-data", "expensive")
      |> get(~p"/")

    assert json_response(conn, 200)["props"]["expensive"] == "loaded"
    assert_received ^ref
    refute_received ^ref
  end

  test "a different component still receives the full page", %{conn: conn, loaded: ref} do
    conn =
      conn
      |> put_req_header("x-inertia-partial-component", "Settings")
      |> put_req_header("x-inertia-partial-data", "errors")
      |> get(~p"/")

    assert json_response(conn, 200)["props"]["expensive"] == "loaded"
    assert_received ^ref
    refute_received ^ref
  end

  @tag :authenticated
  test "requested shared props retain the user and a valid socket token", %{
    conn: conn,
    user: user
  } do
    conn =
      conn
      |> put_req_header("x-inertia-partial-component", "Dashboard")
      |> put_req_header("x-inertia-partial-data", "current_user,socket_token")
      |> get(~p"/dashboard")

    props = json_response(conn, 200)["props"]

    assert props["current_user"] == %{
             "id" => user.id,
             "email" => user.email,
             "locale" => user.locale
           }

    assert Phoenix.Token.verify(
             ElixirReactStarterWeb.Endpoint,
             ElixirReactStarterWeb.UserSocket.token_salt(),
             props["socket_token"],
             max_age: 60
           ) == {:ok, user.id}
  end
end
