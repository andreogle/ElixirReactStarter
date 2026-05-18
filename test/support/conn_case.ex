defmodule WebTemplateWeb.ConnCase do
  @moduledoc """
  Test case for tests that need a `%Plug.Conn{}`.

  ## Tags

    * `@tag :authenticated` — creates a confirmed user, logs them in,
      and merges `%{user: user}` into the test context. The connection
      is ready to make authenticated requests.

  Async tests are safe; the SQL sandbox isolates each test.
  """

  use ExUnit.CaseTemplate

  import WebTemplate.Factory

  using do
    quote do
      @endpoint WebTemplateWeb.Endpoint

      use WebTemplateWeb, :verified_routes

      import Plug.Conn
      import Phoenix.ConnTest
      import WebTemplateWeb.ConnCase
      import WebTemplate.Factory
    end
  end

  setup tags do
    WebTemplate.DataCase.setup_sandbox(tags)
    conn = Phoenix.ConnTest.build_conn()

    if tags[:authenticated] do
      user = :user |> build() |> confirmed() |> insert()
      {:ok, conn: log_in_user(conn, user), user: user}
    else
      {:ok, conn: conn}
    end
  end

  @doc """
  Puts a session token for `user` on `conn`. Use this whenever a test
  needs to authenticate as someone other than the default user from the
  `:authenticated` tag (e.g. switching identity mid-test, multi-user
  scenarios).
  """
  def log_in_user(conn, user) do
    token = WebTemplate.Accounts.generate_user_session_token(user)
    Phoenix.ConnTest.init_test_session(conn, %{"user_token" => token})
  end
end
