defmodule WebTemplateWeb.Plugs.SharedData do
  @moduledoc """
  Inertia plug that assigns the props every page receives.

  Runs after `:fetch_current_user` in the browser pipeline so
  `conn.assigns[:current_user]` and `:locale` are populated.
  """

  import Inertia.Controller

  alias WebTemplateWeb.Endpoint
  alias WebTemplateWeb.UserSocket

  def init(opts), do: opts

  def call(conn, _opts) do
    user = conn.assigns[:current_user]

    conn
    |> assign_prop(:current_user, serialize_user(user))
    |> assign_prop(:locale, conn.assigns[:locale] || "en")
    |> assign_prop(:flash, conn.assigns[:flash] || %{})
    |> assign_prop(:socket_token, socket_token_for(user))
  end

  defp serialize_user(nil), do: nil

  defp serialize_user(user) do
    %{id: user.id, email: user.email, locale: user.locale}
  end

  # Signs a short-lived token the React realtime provider hands to
  # Phoenix.Socket on connect. `nil` for anonymous requests so the
  # provider can branch on `socket_token === null` and skip wiring up
  # the socket entirely.
  defp socket_token_for(nil), do: nil

  defp socket_token_for(user) do
    Phoenix.Token.sign(Endpoint, UserSocket.token_salt(), user.id)
  end
end
