defmodule BackendMockTest do
  use BitPal.IntegrationCase, async: true
  alias BitPal.BackendManager
  alias BitPal.BackendMock
  alias BitPal.Blocks

  describe "auto generate" do
    @tag backends: [
           {BackendMock, auto: true, time_until_tx_seen: 10, time_between_blocks: 5}
         ]
    @tag do: true
    test "auto confirms", %{currency_id: currency_id} do
      {:ok, _inv1, stub1, _invoice_handler} =
        HandlerSubscriberCollector.create_invoice(
          payment_currency_id: currency_id,
          required_confirmations: 1,
          amount: 1.0
        )

      {:ok, _inv3, stub3, _invoice_handler} =
        HandlerSubscriberCollector.create_invoice(
          payment_currency_id: currency_id,
          required_confirmations: 3,
          amount: 3.0
        )

      HandlerSubscriberCollector.await_msg(stub1, {:invoice, :paid})
      HandlerSubscriberCollector.await_msg(stub3, {:invoice, :paid})

      assert [
               {{:invoice, :finalized}, _},
               {{:invoice, :processing}, _},
               {{:invoice, :paid}, _}
             ] = HandlerSubscriberCollector.received(stub1)

      assert [
               {{:invoice, :finalized}, _},
               {{:invoice, :processing}, %{confirmations_due: 3}},
               {{:invoice, :processing}, %{confirmations_due: 2}},
               {{:invoice, :processing}, %{confirmations_due: 1}},
               {{:invoice, :paid}, _}
             ] = HandlerSubscriberCollector.received(stub3)
    end
  end

  describe "control status" do
    test "started by default", %{currency_id: currency_id} do
      assert eventually(fn -> BackendManager.status(currency_id) == :ready end)
    end

    @tag backends: [{BackendMock, status: :starting}]
    test "set status", %{currency_id: currency_id} do
      assert eventually(fn -> BackendManager.status(currency_id) == :starting end)
    end

    test "stopped", %{currency_id: currency_id} do
      BackendManager.stop_backend(currency_id)
      assert eventually(fn -> BackendManager.status(currency_id) == :stopped end)

      assert {:ok, _} = BackendManager.restart_backend(currency_id)
      assert eventually(fn -> BackendManager.status(currency_id) == :ready end)
    end

    @tag backends: [{BitPal.BackendMock, sync_time: 50}]
    test "delayed start", %{currency_id: currency_id} do
      BackendManager.stop_backend(currency_id)
      assert eventually(fn -> BackendManager.status(currency_id) == :stopped end)

      assert {:ok, _} = BackendManager.restart_backend(currency_id)
      assert eventually(fn -> {:syncing, _} = BackendManager.status(currency_id) end)

      assert eventually(fn ->
               BackendManager.status(currency_id) == :ready
             end)
    end

    @tag backends: [
           {BitPal.BackendMock, auto: true, time_until_tx_seen: 10, time_between_blocks: 5}
         ]
    test "stop auto blocks", %{currency_id: currency_id} do
      assert eventually(fn -> BackendManager.status(currency_id) == :ready end)

      assert BackendManager.stop_backend(currency_id) == :ok
      assert eventually(fn -> BackendManager.status(currency_id) == :stopped end)

      height = Blocks.fetch_height!(currency_id)

      Process.sleep(21)
      assert Blocks.fetch_height!(currency_id) == height

      assert {:ok, _} = BackendManager.restart_backend(currency_id)

      assert eventually(fn ->
               Blocks.fetch_height!(currency_id) > height
             end)
    end
  end
end
