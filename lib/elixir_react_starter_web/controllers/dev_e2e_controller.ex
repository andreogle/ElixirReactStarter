defmodule ElixirReactStarterWeb.DevE2EController do
  @moduledoc """
  Dev-only HTTP fixtures for the Playwright E2E suite (`assets/e2e`), backed
  by `ElixirReactStarter.E2EFixtures`.

  Specs that need an existing account `POST /dev/e2e/users` with a unique
  email to mint a *confirmed* user, skipping the email-link confirmation
  round-trip. Specs that exercise the real registration flow don't use
  this — they register through the UI. After every test, pass or fail, the
  suite's fixtures `DELETE /dev/e2e/users` with every email that test
  generated, so a run leaves nothing behind.

  Mounted only when `:dev_routes` is enabled (see `ElixirReactStarterWeb.Router`),
  so it is unreachable in production. As defence in depth it refuses to act
  outside dev and test, and only ever touches `e2e-test-…` emails, so an
  accidental call from real client code can't create or delete real accounts.
  """

  use ElixirReactStarterWeb, :controller

  alias ElixirReactStarter.E2EFixtures

  # Defence in depth: already gated by `:dev_routes` at the router, but a
  # misconfigured release that enables that flag in production should still
  # get a hard 404 here, not a working fixture endpoint.
  plug :require_dev_env

  def create(conn, params) do
    with {:ok, attrs} <- coerce_params(params),
         {:ok, user} <- E2EFixtures.create_user(attrs, params["confirmed"] != false) do
      conn
      |> put_status(:created)
      |> json(%{id: user.id, email: user.email})
    else
      {:error, :invalid_email} ->
        send_error(conn, :forbidden, "email outside the e2e fixture pattern")

      {:error, %Ecto.Changeset{} = changeset} ->
        send_error(conn, :unprocessable_entity, format_changeset_errors(changeset))
    end
  end

  def delete(conn, %{"emails" => emails}) when is_list(emails) do
    json(conn, %{deleted: E2EFixtures.delete_users(emails)})
  end

  def delete(conn, _params), do: send_error(conn, :unprocessable_entity, "emails must be a list")

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------
  defp coerce_params(params) do
    if is_binary(params["email"]) do
      {:ok, %{"email" => params["email"], "password" => params["password"] || random_password()}}
    else
      {:error, :invalid_email}
    end
  end

  # 24 random URL-safe bytes — callers log in with the password they
  # supplied, so we never need to recover this default.
  defp random_password, do: 24 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {k, v}, acc -> String.replace(acc, "%{#{k}}", to_string(v)) end)
    end)
  end

  defp send_error(conn, status, message) do
    conn |> put_status(status) |> json(%{error: message})
  end

  # `Mix.env/0` is captured at compile time, so this burns the build-time
  # environment into the binary — exactly what a dev-only endpoint wants.
  @dev_env? Mix.env() in [:dev, :test]

  # Dialyzer runs in :test (where @dev_env? is true) and flags the else
  # branch as dead. It IS dead in dev/test — and intentionally live in prod.
  @dialyzer {:nowarn_function, require_dev_env: 2}
  defp require_dev_env(conn, _opts) do
    if @dev_env? do
      conn
    else
      conn |> put_status(:not_found) |> json(%{error: "not found"}) |> halt()
    end
  end
end
