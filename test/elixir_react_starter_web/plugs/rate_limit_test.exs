defmodule ElixirReactStarterWeb.Plugs.RateLimitTest do
  # async: false — toggles the global :rate_limit_enabled config.
  use ElixirReactStarterWeb.ConnCase, async: false

  alias ElixirReactStarterWeb.Plugs.RateLimit

  setup do
    Application.put_env(:elixir_react_starter, :rate_limit_enabled, true)
    on_exit(fn -> Application.put_env(:elixir_react_starter, :rate_limit_enabled, false) end)
    :ok
  end

  defp conn_for_path(path) do
    build_conn(:post, path)
    |> init_test_session(%{})
    |> Phoenix.Controller.fetch_flash([])
  end

  test "allows requests up to the limit, then denies with a redirect + Retry-After" do
    # Unique bucket so the test is isolated from any other limiter state.
    opts =
      RateLimit.init(
        bucket: "test:#{System.unique_integer([:positive])}",
        limit: 2,
        scale: 60_000
      )

    conn = conn_for_path("/login")

    refute RateLimit.call(conn, opts).halted
    refute RateLimit.call(conn, opts).halted

    denied = RateLimit.call(conn, opts)
    assert denied.halted
    assert denied.status == 302
    assert get_resp_header(denied, "retry-after") != []
  end

  test "is a no-op when rate limiting is disabled" do
    Application.put_env(:elixir_react_starter, :rate_limit_enabled, false)

    opts =
      RateLimit.init(
        bucket: "test:#{System.unique_integer([:positive])}",
        limit: 1,
        scale: 60_000
      )

    conn = conn_for_path("/login")

    refute RateLimit.call(conn, opts).halted
    refute RateLimit.call(conn, opts).halted
    refute RateLimit.call(conn, opts).halted
  end

  test "keys per email when by: :email, isolating different addresses" do
    opts =
      RateLimit.init(
        bucket: "test:#{System.unique_integer([:positive])}",
        by: :email,
        limit: 1,
        scale: 60_000
      )

    a = %{conn_for_path("/forgot-password") | params: %{"email" => "a@example.com"}}
    b = %{conn_for_path("/forgot-password") | params: %{"email" => "b@example.com"}}

    refute RateLimit.call(a, opts).halted
    # Second hit for the same email is denied...
    assert RateLimit.call(a, opts).halted
    # ...but a different email has its own bucket.
    refute RateLimit.call(b, opts).halted
  end
end
