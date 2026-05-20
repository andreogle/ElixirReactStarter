defmodule ElixirReactStarterWeb.UserSocket do
  @moduledoc """
  The persistent WebSocket every authenticated tab opens. Auth is by
  signed `Phoenix.Token` minted in `ElixirReactStarterWeb.Plugs.SharedData`
  on every page response and rotated as the session changes.

  `id/1` returns a deterministic per-user topic so the application can
  force-disconnect every tab a given user has open (broadcast
  `"disconnect"` on `user_socket:<user_id>`).
  """

  use Phoenix.Socket

  channel "global", ElixirReactStarterWeb.GlobalChannel
  channel "user:*", ElixirReactStarterWeb.UserChannel

  # 7 days. The client refreshes the token on every Inertia page load,
  # so in practice the lifetime is "this browsing session"; the upper
  # bound prevents long-stolen tokens from being replayed.
  @max_age 7 * 24 * 3600

  @impl Phoenix.Socket
  def connect(%{"token" => token}, socket, _connect_info) do
    case Phoenix.Token.verify(ElixirReactStarterWeb.Endpoint, token_salt(), token,
           max_age: @max_age
         ) do
      {:ok, user_id} -> {:ok, assign(socket, :user_id, user_id)}
      {:error, _reason} -> :error
    end
  end

  def connect(_params, _socket, _connect_info), do: :error

  @impl Phoenix.Socket
  def id(socket), do: "user_socket:#{socket.assigns.user_id}"

  @doc """
  The salt used by both signing (in SharedData) and verification (here).
  Exposed as a function so callers can't drift on the string literal.
  """
  def token_salt, do: "user socket"
end
