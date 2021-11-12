defmodule BitPal.Backend.FloweeTest do
  use BitPal.DataCase
  import Mox
  import BitPal.MockTCPClient
  alias BitPal.Backend.Flowee
  alias BitPal.Backend.FloweeFixtures
  alias BitPal.Blocks
  alias BitPal.MockTCPClient
  alias BitPal.HandlerSubscriberCollector

  @currency :BCH
  @xpub Application.compile_env!(:bitpal, [:BCH, :xpub])
  @client FloweeMock

  setup :set_mox_from_context

  setup do
    init_mock(@client)
    %{store: insert(:store)}
  end

  setup tags do
    # Some tests don't want to have the initialization automatically enabled.
    if Map.get(tags, :init_message, true) do
      MockTCPClient.response(@client, FloweeFixtures.blockchain_info())
    end

    # FIXME make this async!

    manager_name = unique_server_name()

    start_supervised!(
      {BitPal.BackendManager,
       backends: [
         {BitPal.Backend.Flowee,
          tcp_client: @client, ping_timeout: tags[:ping_timeout] || :timer.minutes(1)}
       ],
       name: manager_name}
    )

    on_exit(fn ->
      BitPal.IntegrationCase.remove_invoice_handlers([@currency])
    end)

    Map.merge(tags, %{
      manager_name: manager_name
    })
  end

  defp create_invoice(params) do
    params
    |> Enum.into(%{
      address_key: @xpub,
      currency_id: @currency
    })
    |> HandlerSubscriberCollector.create_invoice()
  end

  @tag ping_timeout: 1
  test "ping/pong" do
    # Pong doesn't do anything, just ensure we parse it
    MockTCPClient.response(@client, FloweeFixtures.pong())
    Process.sleep(1)

    assert eventually(fn -> MockTCPClient.last_sent(@client) == FloweeFixtures.ping() end)
  end

  test "new block" do
    assert eventually(fn ->
             Blocks.fetch_block_height(@currency) == {:ok, 690_637}
           end)

    MockTCPClient.response(@client, FloweeFixtures.new_block())

    assert eventually(fn ->
             Blocks.fetch_block_height(@currency) == {:ok, 690_638}
           end)
  end

  test "transaction 0-conf acceptance", %{store: store, manager_name: manager_name} do
    {:ok, _inv, stub, _invoice_handler} =
      create_invoice(
        store: store,
        required_confirmations: 0,
        amount: 0.000_01,
        double_spend_timeout: 1,
        manager_name: manager_name
      )

    MockTCPClient.response(@client, FloweeFixtures.tx_seen())
    HandlerSubscriberCollector.await_msg(stub, :invoice_paid)

    assert [
             {:invoice_finalized, _},
             {:invoice_processing, _},
             {:invoice_paid, _}
           ] = HandlerSubscriberCollector.received(stub)
  end

  test "transaction confirmation acceptance", %{store: store} do
    {:ok, _inv, stub, _invoice_handler} =
      create_invoice(
        store: store,
        required_confirmations: 1,
        amount: 0.000_01
      )

    MockTCPClient.response(@client, FloweeFixtures.tx_1_conf())
    MockTCPClient.response(@client, FloweeFixtures.new_block())
    HandlerSubscriberCollector.await_msg(stub, :invoice_paid)

    assert [
             {:invoice_finalized, _},
             {:invoice_processing, _},
             {:invoice_paid, _}
           ] = HandlerSubscriberCollector.received(stub)
  end

  test "single tx 0-conf to multiple monitored addresses", %{store: store} do
    {:ok, _invoice, stub1, _invoice_handler} =
      create_invoice(
        store: store,
        double_spend_timeout: 1,
        required_confirmations: 0,
        amount: 0.000_1,
        address: "bitcoincash:qrwjyrzae2av8wxvt79e2ukwl9q58m3u6cwn8k2dpa"
      )

    {:ok, _invoice, stub2, _invoice_handler} =
      create_invoice(
        store: store,
        double_spend_timeout: 1,
        required_confirmations: 0,
        amount: 0.000_2,
        address: "bitcoincash:qz96wvrhsrg9j3rnczg7jkh3dlgshtcxzu89qrrcgc"
      )

    MockTCPClient.response(@client, FloweeFixtures.multi_tx_seen())
    HandlerSubscriberCollector.await_msg(stub1, :invoice_paid)
    HandlerSubscriberCollector.await_msg(stub2, :invoice_paid)

    assert [
             {:invoice_finalized, _},
             {:invoice_processing, _},
             {:invoice_paid, _}
           ] = HandlerSubscriberCollector.received(stub1)

    assert [
             {:invoice_finalized, _},
             {:invoice_processing, _},
             {:invoice_paid, _}
           ] = HandlerSubscriberCollector.received(stub2)
  end

  @tag double_spend_timeout: 1
  test "multiple tx 0-conf to multiple monitored addresses", %{store: store} do
    {:ok, _invoice, stub1, _invoice_handler} =
      create_invoice(
        store: store,
        double_spend_timeout: 1,
        required_confirmations: 0,
        amount: 0.000_15,
        address: "bitcoincash:qrwjyrzae2av8wxvt79e2ukwl9q58m3u6cwn8k2dpa"
      )

    {:ok, _invoice, stub2, _invoice_handler} =
      create_invoice(
        store: store,
        double_spend_timeout: 1,
        required_confirmations: 0,
        amount: 0.000_2,
        address: "bitcoincash:qz96wvrhsrg9j3rnczg7jkh3dlgshtcxzu89qrrcgc"
      )

    # Give 10000 to the first one, and 20000 to the second one
    MockTCPClient.response(@client, FloweeFixtures.multi_tx_seen())

    # There's a race condition here where we might store the txs in the db
    # at the same time, causing us to miss the `invoice_underpaid` event.
    # This has no importance in the real world, but may screw up the test if
    # we don't have this wait between.
    HandlerSubscriberCollector.await_msg(stub2, :invoice_paid)

    # Give 5000 to the first one.
    MockTCPClient.response(@client, FloweeFixtures.multi_tx_a_seen())

    HandlerSubscriberCollector.await_msg(stub1, :invoice_paid)

    assert [
             {:invoice_finalized, _},
             {:invoice_underpaid, _},
             {:invoice_processing, _},
             {:invoice_paid, _}
           ] = HandlerSubscriberCollector.received(stub1)

    assert [
             {:invoice_finalized, _},
             {:invoice_processing, _},
             {:invoice_paid, _}
           ] = HandlerSubscriberCollector.received(stub2)
  end

  @tag double_spend_timeout: 1
  test "single tx 1-conf to multiple monitored addresses", %{store: store} do
    {:ok, _invoice, stub1, _invoice_handler} =
      create_invoice(
        store: store,
        double_spend_timeout: 1,
        required_confirmations: 1,
        amount: 0.000_1,
        address: "bitcoincash:qrwjyrzae2av8wxvt79e2ukwl9q58m3u6cwn8k2dpa"
      )

    {:ok, _invoice, stub2, _invoice_handler} =
      create_invoice(
        store: store,
        double_spend_timeout: 1,
        required_confirmations: 1,
        amount: 0.000_2,
        address: "bitcoincash:qz96wvrhsrg9j3rnczg7jkh3dlgshtcxzu89qrrcgc"
      )

    MockTCPClient.response(@client, FloweeFixtures.multi_tx_seen())

    HandlerSubscriberCollector.await_msg(stub1, :invoice_processing)
    HandlerSubscriberCollector.await_msg(stub2, :invoice_processing)

    assert [
             {:invoice_finalized, _},
             {:invoice_processing, _}
           ] = HandlerSubscriberCollector.received(stub1)

    assert [
             {:invoice_finalized, _},
             {:invoice_processing, _}
           ] = HandlerSubscriberCollector.received(stub2)

    MockTCPClient.response(@client, FloweeFixtures.multi_tx_1_conf())
    # Manually set blocks to avoid having to find fixtures for all things
    Blocks.new_block(@currency, 690_933)

    HandlerSubscriberCollector.await_msg(stub1, :invoice_paid)
    HandlerSubscriberCollector.await_msg(stub2, :invoice_paid)

    assert [
             {:invoice_finalized, _},
             {:invoice_processing, _},
             {:invoice_paid, _}
           ] = HandlerSubscriberCollector.received(stub1)

    assert [
             {:invoice_finalized, _},
             {:invoice_processing, _},
             {:invoice_paid, _}
           ] = HandlerSubscriberCollector.received(stub2)
  end

  @tag double_spend_timeout: 1
  test "multiple tx 1-conf to multiple monitored addresses", %{store: store} do
    {:ok, _invoice, stub1, _invoice_handler} =
      create_invoice(
        store: store,
        double_spend_timeout: 1,
        required_confirmations: 1,
        amount: 0.000_15,
        address: "bitcoincash:qrwjyrzae2av8wxvt79e2ukwl9q58m3u6cwn8k2dpa"
      )

    {:ok, _invoice, stub2, _invoice_handler} =
      create_invoice(
        store: store,
        double_spend_timeout: 1,
        required_confirmations: 1,
        amount: 0.000_2,
        address: "bitcoincash:qz96wvrhsrg9j3rnczg7jkh3dlgshtcxzu89qrrcgc"
      )

    # Give 10000 to the first one, and 20000 to the second one
    MockTCPClient.response(@client, FloweeFixtures.multi_tx_seen())

    # Confirm the first transaction.
    MockTCPClient.response(@client, FloweeFixtures.multi_tx_1_conf())
    # Manually set blocks to avoid having to find fixtures for all things
    Blocks.new_block(@currency, 690_933)

    HandlerSubscriberCollector.await_msg(stub1, :invoice_finalized)
    HandlerSubscriberCollector.await_msg(stub2, :invoice_paid)

    assert [
             {:invoice_finalized, _},
             {:invoice_underpaid, _}
           ] = HandlerSubscriberCollector.received(stub1)

    assert [
             {:invoice_finalized, _},
             {:invoice_processing, _},
             {:invoice_paid, _}
           ] = HandlerSubscriberCollector.received(stub2)

    # Give 5000 to the first one.
    MockTCPClient.response(@client, FloweeFixtures.multi_tx_a_seen())

    # And confirm.
    MockTCPClient.response(@client, FloweeFixtures.multi_tx_a_1_conf())
    # Manually set blocks to avoid having to find fixtures for all things
    Blocks.new_block(@currency, 690_934)

    HandlerSubscriberCollector.await_msg(stub1, :invoice_paid)

    assert [
             {:invoice_finalized, _},
             {:invoice_underpaid, _},
             {:invoice_processing, _},
             {:invoice_paid, _}
           ] = HandlerSubscriberCollector.received(stub1)
  end

  # NOTE that this test sometimes times out
  @tag init_message: false
  test "wait for Flowee to become ready" do
    # Send it an incomplete startup message to get it going.
    MockTCPClient.response(@client, FloweeFixtures.blockchain_verifying_info())

    # Wait a bit to let it act.
    :timer.sleep(10)

    # It should not be ready yet, Flowee is still preparing.
    assert Flowee.ready?(BitPal.Backend.Flowee) == false

    # Give it a new message, now it should be done!
    MockTCPClient.response(@client, FloweeFixtures.blockchain_info())
    assert eventually(fn -> Flowee.ready?(BitPal.Backend.Flowee) end)
  end

  @tag init_message: false
  test "make sure recovery works", %{store: store} do
    # Simulate the state stored in the DB:
    {:ok, _invoice, stub1, _invoice_handler} =
      create_invoice(
        store: store,
        required_confirmations: 1,
        amount: 0.000_15,
        address: "bitcoincash:qrwjyrzae2av8wxvt79e2ukwl9q58m3u6cwn8k2dpa"
      )

    {:ok, _invoice, stub2, _invoice_handler} =
      create_invoice(
        store: store,
        required_confirmations: 1,
        amount: 0.000_2,
        address: "bitcoincash:qz96wvrhsrg9j3rnczg7jkh3dlgshtcxzu89qrrcgc"
      )

    # We are now at height 690933:
    Blocks.set_block_height(@currency, 690_932)

    # Now, we tell Flowee the current block height. It will try to recover, and ask for the missing
    # block.
    MockTCPClient.response(@client, FloweeFixtures.blockchain_info_690933())

    # Note: The addresses may be in any order, so we check for both of them.
    assert eventually(fn ->
             last = MockTCPClient.last_sent(@client)

             last == FloweeFixtures.block_info_query_690933_a() ||
               last == FloweeFixtures.block_info_query_690933_b()
           end)

    # At this point, Flowee should not report being ready.
    assert Flowee.ready?(BitPal.Backend.Flowee) == false

    # Tell it what happened:
    MockTCPClient.response(@client, FloweeFixtures.block_info_690933())

    # It will ask for block info again, so that it can properly capture if Flowee managed to find
    # another block while it updated the last block. At this point, it should be happy.
    MockTCPClient.response(@client, FloweeFixtures.blockchain_info_690933())

    # Both should be paid by now.
    HandlerSubscriberCollector.await_msg(stub1, :invoice_paid)
    HandlerSubscriberCollector.await_msg(stub2, :invoice_paid)

    # It should also be ready now.
    assert Flowee.ready?(BitPal.Backend.Flowee) == true
  end

  # Things we need to test:
  #
  # version
  # double spend
end
