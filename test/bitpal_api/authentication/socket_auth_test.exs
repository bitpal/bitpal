defmodule BitPalApi.SocketAuthTest do
  use BitPalApi.ChannelCase, async: true

  test "successful auth with headers" do
    %{store_id: _store_id, token: token} = AuthFixtures.auth_fixture()

    {:ok, _socket} =
      connect(BitPalApi.StoreSocket, %{}, %{x_headers: [{"x-access-token", token}]})
  end

  test "successful auth with params" do
    %{store_id: _store_id, token: token} = AuthFixtures.auth_fixture()

    {:ok, _socket} = connect(BitPalApi.StoreSocket, %{"token" => token}, %{})
  end

  test "no auth" do
    :error = connect(BitPalApi.StoreSocket, %{})
  end

  test "bad auth with headers" do
    :error = connect(BitPalApi.StoreSocket, %{"token" => "bad-token"})
  end

  test "bad auth with params" do
    :error = connect(BitPalApi.StoreSocket, %{}, %{x_headers: [{"x-access-token", "bad-token"}]})
  end
end
