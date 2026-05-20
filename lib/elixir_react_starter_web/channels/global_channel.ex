defmodule ElixirReactStarterWeb.GlobalChannel do
  @moduledoc """
  App-wide broadcast channel. Auto-joined by every authenticated tab
  via the realtime provider. Use this for announcements / system
  events that any signed-in user should see.

  No authz beyond "user passed UserSocket auth" — if a topic needs
  per-user gating, send it on `user:<id>` instead.
  """

  use ElixirReactStarterWeb, :channel

  @impl Phoenix.Channel
  def join("global", _payload, socket) do
    {:ok, socket}
  end
end
