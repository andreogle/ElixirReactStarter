defmodule ElixirReactStarterWeb.Plugs.DocsIndexRedirect do
  @moduledoc """
  Redirects `/dev/docs` and `/dev/docs/` to `/dev/docs/index.html`.

  Two reasons we use a 302 rather than rewriting the path internally:

    * `Plug.Static` doesn't auto-serve directory indexes, so without a
      redirect both URLs fall through to the router and 404.
    * Relative links inside ex_doc's HTML (`<a href="api-reference.html">`)
      resolve against the URL bar's directory. If we served `index.html`
      under the URL `/dev/docs`, relative links would resolve to
      `/dev/api-reference.html` — wrong dir, 404. The redirect lands the
      user at a URL whose directory is `/dev/docs/`, so links work.

  Mounted in the endpoint immediately before the dev-only docs
  `Plug.Static`. Compile-time gated alongside it.
  """

  @behaviour Plug

  import Plug.Conn

  @impl true
  def init(_opts), do: nil

  @impl true
  def call(%Plug.Conn{path_info: path_info} = conn, _opts)
      when path_info in [["dev", "docs"], ["dev", "docs", ""]] do
    conn
    |> put_resp_header("location", "/dev/docs/index.html")
    |> send_resp(302, "")
    |> halt()
  end

  def call(conn, _opts), do: conn
end
