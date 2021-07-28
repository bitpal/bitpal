defmodule BitPalApi.SocketAuthTest do
  use BitPalApi.ChannelCase

  test "successful auth" do
    %{store_id: _store_id, token: token} = create_auth()

    {:ok, _socket} =
      connect(BitPalApi.StoreSocket, %{}, %{x_headers: [{"x-access-token", token}]})
  end

  test "no auth" do
    :error = connect(BitPalApi.StoreSocket, %{})
  end

  test "bad auth" do
    :error = connect(BitPalApi.StoreSocket, %{"token" => "bad-token"})
  end
end
