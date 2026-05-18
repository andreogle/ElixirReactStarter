defmodule WebTemplateWeb.Plugs.SharedData do
  @moduledoc """
  Inertia plug that assigns the props every page receives.

  Runs after `:fetch_current_user` in the browser pipeline so
  `conn.assigns[:current_user]` and `:locale` are populated.
  """

  import Inertia.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> assign_prop(:current_user, serialize_user(conn.assigns[:current_user]))
    |> assign_prop(:locale, conn.assigns[:locale] || "en")
    |> assign_prop(:flash, conn.assigns[:flash] || %{})
  end

  defp serialize_user(nil), do: nil

  defp serialize_user(user) do
    %{id: user.id, email: user.email}
  end
end
