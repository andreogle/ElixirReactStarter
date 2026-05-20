defmodule WebTemplateWeb.DevE2EController do
  @moduledoc """
  Dev-only HTTP fixture provisioning for the Playwright E2E suite
  (`assets/e2e`).

  Specs that need an existing account `POST /dev/e2e/users` with a unique
  email to mint a *confirmed* user, skipping the email-link confirmation
  round-trip. Specs that exercise the real registration flow don't use
  this — they register through the UI.

  Mounted only when `:dev_routes` is enabled (see `WebTemplateWeb.Router`),
  so it is unreachable in production. As defence in depth it also rejects
  any email outside the `e2e-test-...` pattern — the same pattern the
  `priv/repo/e2e.exs` cleanup deletes — so an accidental call from real
  client code can't stamp accounts into the database.
  """

  use WebTemplateWeb, :controller

  alias WebTemplate.Accounts

  # Defence in depth: already gated by `:dev_routes` at the router, but a
  # misconfigured release that enables that flag in production should still
  # get a hard 404 here, not a working fixture endpoint.
  plug :require_dev_env

  # Mirrors the cleanup pattern in priv/repo/e2e.exs, so anything minted
  # here is wiped on the next E2E global-setup pass.
  @allowed_email ~r/^e2e-test-[a-z0-9-]+@/i

  def create(conn, params) do
    with {:ok, attrs} <- coerce_params(params),
         :ok <- ensure_allowed_email(attrs["email"]),
         {:ok, user} <- Accounts.create_user(attrs),
         {:ok, user} <- Accounts.confirm_user(user) do
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

  defp ensure_allowed_email(email) do
    if Regex.match?(@allowed_email, email), do: :ok, else: {:error, :invalid_email}
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
