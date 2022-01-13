defmodule BackendMockTest do
  use BitPal.IntegrationCase, async: true
  alias BitPal.Backend
  alias BitPal.Blocks

  describe "auto generate" do
    @tag backends: [
           {BitPal.BackendMock, auto: true, time_until_tx_seen: 10, time_between_blocks: 5}
         ]
    test "auto confirms", %{currency_id: currency_id} do
      {:ok, _inv1, stub1, _invoice_handler} =
        HandlerSubscriberCollector.create_invoice(
          currency_id: currency_id,
          required_confirmations: 1,
          amount: 1.0
        )

      {:ok, _inv3, stub3, _invoice_handler} =
        HandlerSubscriberCollector.create_invoice(
          currency_id: currency_id,
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
               {{:invoice, :processing}, _},
               {{:invoice, :processing}, _},
               {{:invoice, :processing}, _},
               {{:invoice, :paid}, _}
             ] = HandlerSubscriberCollector.received(stub3)
    end
  end

  describe "control status" do
    @tag backends: [BitPal.BackendMock]
    test "started by default", %{backend: backend} do
      assert Backend.status(backend) == {:started, :ready}
    end

    @tag backends: [
           {BitPal.BackendMock, status: :stopped}
         ]
    test "stopped", %{backend: backend} do
      assert Backend.status(backend) == :stopped

      assert Backend.start(backend) == :ok
      assert Backend.status(backend) == {:started, :ready}
    end

    @tag backends: [
           {BitPal.BackendMock, status: :stopped, sync_time: 50}
         ]
    test "delayed start", %{backend: backend} do
      assert Backend.status(backend) == :stopped

      assert Backend.start(backend) == :ok
      assert {:started, {:syncing, _}} = Backend.status(backend)

      assert eventually(fn ->
               Backend.status(backend) == {:started, :ready}
             end)
    end

    @tag backends: [
           {BitPal.BackendMock, auto: true, time_until_tx_seen: 10, time_between_blocks: 5}
         ]
    test "stop auto blocks", %{currency_id: currency_id, backend: backend} do
      assert Backend.stop(backend) == :ok
      height = Blocks.fetch_block_height!(currency_id)

      Process.sleep(21)
      assert Blocks.fetch_block_height!(currency_id) == height

      assert Backend.start(backend) == :ok

      assert eventually(fn ->
               Blocks.fetch_block_height!(currency_id) > height
             end)
    end
  end
end
