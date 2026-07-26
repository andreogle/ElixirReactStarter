defmodule ElixirReactStarterWeb.Plugs.ClientIpTest do
  # async: false — toggles the global :trust_proxy_headers config.
  use ElixirReactStarterWeb.ConnCase, async: false

  alias ElixirReactStarterWeb.Plugs.ClientIp

  @opts ClientIp.init([])

  setup do
    on_exit(fn ->
      Application.delete_env(:elixir_react_starter, :trust_proxy_headers)
      Application.delete_env(:elixir_react_starter, :trusted_proxies)
      Application.delete_env(:elixir_react_starter, :client_ip_headers)
    end)

    :ok
  end

  defp trust_proxy_headers(proxies \\ []) do
    Application.put_env(:elixir_react_starter, :trust_proxy_headers, true)
    Application.put_env(:elixir_react_starter, :trusted_proxies, proxies)
  end

  # The peer address Plug.Test gives us, standing in for the connection the
  # app actually accepted (the proxy, in a real deployment).
  defp conn_with_forwarded_for(value) do
    :get
    |> build_conn("/")
    |> Map.put(:remote_ip, {127, 0, 0, 1})
    |> put_req_header("x-forwarded-for", value)
  end

  describe "when proxy headers are not trusted (the default)" do
    test "ignores x-forwarded-for so a caller can't spoof its address" do
      conn = ClientIp.call(conn_with_forwarded_for("9.9.9.9"), @opts)

      assert conn.remote_ip == {127, 0, 0, 1}
    end
  end

  describe "when proxy headers are trusted" do
    test "uses the address the proxy appended" do
      trust_proxy_headers()

      conn = ClientIp.call(conn_with_forwarded_for("203.0.113.7"), @opts)

      assert conn.remote_ip == {203, 0, 113, 7}
    end

    test "takes the rightmost untrusted address, so a spoofed prefix is ignored" do
      trust_proxy_headers()

      # A caller sent `X-Forwarded-For: 9.9.9.9` and the proxy appended the
      # address it actually saw. Right-to-left means the real one wins.
      conn = ClientIp.call(conn_with_forwarded_for("9.9.9.9, 203.0.113.7"), @opts)

      assert conn.remote_ip == {203, 0, 113, 7}
    end

    test "skips private-range hops without needing them configured" do
      trust_proxy_headers()

      conn = ClientIp.call(conn_with_forwarded_for("203.0.113.7, 10.0.0.5"), @opts)

      assert conn.remote_ip == {203, 0, 113, 7}
    end

    test "skips proxies on public addresses when their range is configured" do
      trust_proxy_headers(["198.51.100.0/24"])

      conn = ClientIp.call(conn_with_forwarded_for("203.0.113.7, 198.51.100.42"), @opts)

      assert conn.remote_ip == {203, 0, 113, 7}
    end

    test "without that configuration the public proxy is mistaken for the client" do
      trust_proxy_headers()

      conn = ClientIp.call(conn_with_forwarded_for("203.0.113.7, 198.51.100.42"), @opts)

      assert conn.remote_ip == {198, 51, 100, 42}
    end

    test "reads an alternative header when one is configured" do
      trust_proxy_headers()
      Application.put_env(:elixir_react_starter, :client_ip_headers, ["cf-connecting-ip"])

      conn =
        :get
        |> build_conn("/")
        |> Map.put(:remote_ip, {127, 0, 0, 1})
        |> put_req_header("cf-connecting-ip", "203.0.113.7")
        # Not in the configured header list, so it must be ignored.
        |> put_req_header("x-forwarded-for", "9.9.9.9")

      assert ClientIp.call(conn, @opts).remote_ip == {203, 0, 113, 7}
    end

    test "falls back to the peer address when no forwarding header is present" do
      trust_proxy_headers()

      conn = ClientIp.call(Map.put(build_conn(:get, "/"), :remote_ip, {127, 0, 0, 1}), @opts)

      assert conn.remote_ip == {127, 0, 0, 1}
    end
  end
end
