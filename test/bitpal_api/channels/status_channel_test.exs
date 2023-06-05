defmodule BitPalApi.StatusChannelTest do
  use BitPalApi.ChannelCase, async: true, integration: true
  alias BitPal.BackendManager
  alias BitPal.Currencies

  setup do
    {:ok, reply, socket} =
      BitPalApi.StoreSocket
      |> socket("user_id", %{some: :assign})
      |> subscribe_and_join(BitPalApi.StatusChannel, "status")

    %{socket: socket, reply: reply}
  end

  describe "reply on join" do
    test "reply with all statuses", %{reply: reply} do
      assert Enum.count(reply) > 0
      [%{currency: currency_id, status: status} | _] = reply
      assert Currencies.is_crypto(currency_id)
      assert status in [:ready, :unavailable]
    end
  end

  describe "updates status" do
    test "stop and start", %{currency_id: currency_id} do
      assert_broadcast("backend_status", %{
        currency: ^currency_id,
        status: :ready
      })

      BackendManager.stop_backend(currency_id)

      assert_broadcast("backend_status", %{
        currency: ^currency_id,
        status: :unavailable
      })

      BackendManager.restart_backend(currency_id)

      assert_broadcast("backend_status", %{
        currency: ^currency_id,
        status: :ready
      })
    end
  end

  describe "get status" do
    test "get backend status", %{socket: socket} do
      ref = push(socket, "backends", %{})

      assert_reply(ref, :ok, status)

      assert Enum.count(status) > 0
    end
  end
end
