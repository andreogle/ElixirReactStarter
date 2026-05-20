defmodule ElixirReactStarterWeb.UserChannelTest do
  use ElixirReactStarterWeb.ChannelCase, async: true

  alias ElixirReactStarterWeb.Endpoint
  alias ElixirReactStarterWeb.UserSocket

  setup do
    user = :user |> build() |> confirmed() |> insert()
    token = Phoenix.Token.sign(Endpoint, UserSocket.token_salt(), user.id)
    {:ok, socket} = connect(UserSocket, %{"token" => token})
    %{socket: socket, user: user}
  end

  test "a user can join their own user:<id> channel", %{socket: socket, user: user} do
    assert {:ok, _, _socket} =
             subscribe_and_join(socket, ElixirReactStarterWeb.UserChannel, "user:#{user.id}")
  end

  test "a user cannot join someone else's user:<id> channel", %{socket: socket} do
    other = :user |> build() |> confirmed() |> insert()

    assert {:error, %{reason: "unauthorized"}} =
             subscribe_and_join(socket, ElixirReactStarterWeb.UserChannel, "user:#{other.id}")
  end
end
