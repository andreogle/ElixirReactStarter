defmodule ElixirReactStarterWeb.EndpointStaticTest do
  use ElixirReactStarterWeb.ConnCase, async: true

  @content "static asset test"
  @brotli Base.decode64!("CwiAc3RhdGljIGFzc2V0IHRlc3QD")

  setup do
    static_dir = Application.app_dir(:elixir_react_starter, "priv/static")
    digest = :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
    icon = "favicon-#{digest}.ico"
    asset = "assets/static-test-#{digest}.txt"
    files = [icon, asset, asset <> ".br", asset <> ".gz"]
    on_exit(fn -> Enum.each(files, &File.rm(Path.join(static_dir, &1))) end)

    File.mkdir_p!(Path.join(static_dir, "assets"))
    File.write!(Path.join(static_dir, icon), @content)
    File.write!(Path.join(static_dir, asset), @content)
    File.write!(Path.join(static_dir, asset <> ".br"), @brotli)
    File.write!(Path.join(static_dir, asset <> ".gz"), :zlib.gzip(@content))
    %{icon: "/" <> icon, asset: "/" <> asset}
  end

  test "serves digested root-level static files", %{conn: conn, icon: icon} do
    assert conn |> get(icon) |> response(200) == @content
  end

  test "prefers Brotli when the client accepts both encodings", %{conn: conn, asset: asset} do
    conn = conn |> put_req_header("accept-encoding", "gzip, br") |> get(asset)

    assert response(conn, 200) == @brotli
    assert get_resp_header(conn, "content-encoding") == ["br"]
    assert "accept-encoding" in Enum.map(get_resp_header(conn, "vary"), &String.downcase/1)
  end

  test "still serves gzip and uncompressed responses", %{conn: conn, asset: asset} do
    compressed = conn |> put_req_header("accept-encoding", "gzip") |> get(asset)
    assert get_resp_header(compressed, "content-encoding") == ["gzip"]
    assert compressed |> response(200) |> :zlib.gunzip() == @content

    plain = get(conn, asset)
    assert response(plain, 200) == @content
    assert get_resp_header(plain, "content-encoding") == []
  end
end
