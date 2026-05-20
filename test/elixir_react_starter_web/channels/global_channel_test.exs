defmodule ElixirReactStarterWeb.GlobalChannelTest do
  use ElixirReactStarterWeb.ChannelCase, async: true

  alias ElixirReactStarterWeb.Endpoint
  alias ElixirReactStarterWeb.UserSocket

  setup do
    user = :user |> build() |> confirmed() |> insert()
    token = Phoenix.Token.sign(Endpoint, UserSocket.token_salt(), user.id)
    {:ok, socket} = connect(UserSocket, %{"token" => token})
    %{socket: socket, user: user}
  end

  test "any authenticated user can join `global`", %{socket: socket} do
    assert {:ok, _, _socket} =
             subscribe_and_join(socket, ElixirReactStarterWeb.GlobalChannel, "global")
  end
end
