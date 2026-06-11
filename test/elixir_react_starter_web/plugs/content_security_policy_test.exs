defmodule ElixirReactStarterWeb.Plugs.ContentSecurityPolicyTest do
  use ExUnit.Case, async: false

  import Plug.Test
  import Plug.Conn

  alias ElixirReactStarterWeb.Plugs.ContentSecurityPolicy

  defp call(conn \\ conn(:get, "/")) do
    ContentSecurityPolicy.call(conn, ContentSecurityPolicy.init([]))
  end

  defp csp(conn), do: get_resp_header(conn, "content-security-policy") |> List.first()

  test "assigns a per-request nonce and references it in script-src" do
    conn = call()
    nonce = conn.assigns.csp_nonce

    assert is_binary(nonce) and nonce != ""
    assert csp(conn) =~ "'nonce-#{nonce}'"
  end

  test "the nonce differs between requests" do
    refute call().assigns.csp_nonce == call().assigns.csp_nonce
  end

  test "always forbids framing, plugins, and base-tag hijacking" do
    header = csp(call())
    assert header =~ "frame-ancestors 'none'"
    assert header =~ "object-src 'none'"
    assert header =~ "base-uri 'self'"
  end

  describe "strict profile" do
    setup do
      Application.put_env(:elixir_react_starter, :content_security_policy, :strict)
      on_exit(fn -> Application.delete_env(:elixir_react_starter, :content_security_policy) end)
    end

    test "uses strict-dynamic and omits unsafe-eval" do
      header = csp(call())
      assert header =~ "'strict-dynamic'"
      refute header =~ "'unsafe-eval'"
    end
  end

  describe "relaxed profile (default)" do
    test "allows unsafe-eval and localhost websockets for dev tooling" do
      header = csp(call())
      assert header =~ "'unsafe-eval'"
      assert header =~ "ws:"
    end
  end

  describe ":csp_extra_sources" do
    setup do
      Application.put_env(:elixir_react_starter, :csp_extra_sources,
        script_src: ["https://js.stripe.com"],
        img_src: ["https://cdn.example.com"]
      )

      on_exit(fn -> Application.delete_env(:elixir_react_starter, :csp_extra_sources) end)
    end

    test "merges extra origins into the matching directive" do
      header = csp(call())
      assert header =~ "https://js.stripe.com"
      assert header =~ "https://cdn.example.com"
    end
  end
end
