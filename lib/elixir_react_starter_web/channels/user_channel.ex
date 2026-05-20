defmodule ElixirReactStarterWeb.UserChannel do
  @moduledoc """
  Personal per-user channel. The provider auto-joins `user:<own_id>`;
  the server rejects joins for any other user id so a forged topic
  string from the browser console can't escape this boundary.

  Use this for direct-to-user pushes — notifications, "your data
  changed", etc.
  """

  use ElixirReactStarterWeb, :channel

  @impl Phoenix.Channel
  def join("user:" <> user_id, _payload, socket) do
    if user_id == socket.assigns.user_id do
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end
end
