defmodule WebTemplateWeb.UserSocketTest do
  use WebTemplateWeb.ChannelCase, async: true

  alias WebTemplateWeb.Endpoint
  alias WebTemplateWeb.UserSocket

  describe "connect/3" do
    test "accepts a valid token and assigns user_id" do
      user = :user |> build() |> confirmed() |> insert()
      token = Phoenix.Token.sign(Endpoint, UserSocket.token_salt(), user.id)

      assert {:ok, socket} = connect(UserSocket, %{"token" => token})
      assert socket.assigns.user_id == user.id
    end

    test "rejects a missing token" do
      assert :error = connect(UserSocket, %{})
    end

    test "rejects a malformed token" do
      assert :error = connect(UserSocket, %{"token" => "not-a-real-token"})
    end

    test "rejects a token signed with the wrong salt" do
      user = :user |> build() |> confirmed() |> insert()
      bad = Phoenix.Token.sign(Endpoint, "different salt", user.id)

      assert :error = connect(UserSocket, %{"token" => bad})
    end
  end

  describe "id/1" do
    test "returns a deterministic per-user topic" do
      user = :user |> build() |> confirmed() |> insert()
      token = Phoenix.Token.sign(Endpoint, UserSocket.token_salt(), user.id)
      {:ok, socket} = connect(UserSocket, %{"token" => token})

      assert UserSocket.id(socket) == "user_socket:#{user.id}"
    end
  end
end
