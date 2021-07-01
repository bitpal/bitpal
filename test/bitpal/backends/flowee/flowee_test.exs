defmodule BitPal.Backend.FloweeTest do
  use BitPal.IntegrationCase
  import Mox
  import BitPal.MockTCPClient
  alias BitPal.Backend.FloweeFixtures
  alias BitPal.Blocks
  alias BitPal.MockTCPClient

  @client FloweeMock

  setup :set_mox_from_context

  setup tags do
    init_mock(@client)

    # Some tests don't want to have the initialization automatically enabled.
    if Map.get(tags, :init_message, true) do
      MockTCPClient.response(@client, FloweeFixtures.blockchain_info())
    end

    start_supervised!(
      {BitPal.BackendManager,
       backends: [
         {BitPal.Backend.Flowee,
          tcp_client: @client, ping_timeout: tags[:ping_timeout] || :timer.minutes(1)}
       ]}
    )

    :ok
  end

  @tag backends: [], ping_timeout: 1
  test "ping/pong" do
    # Pong doesn't do anything, just ensure we parse it
    MockTCPClient.response(@client, FloweeFixtures.pong())
    Process.sleep(1)

    assert eventually(fn -> MockTCPClient.last_sent(@client) == FloweeFixtures.ping() end)
  end

  @tag backends: []
  test "new block" do
    assert eventually(fn ->
             Blocks.get_block_height(:BCH) == 690_637
           end)

    MockTCPClient.response(@client, FloweeFixtures.new_block())

    assert eventually(fn ->
             Blocks.get_block_height(:BCH) == 690_638
           end)
  end

  @tag backends: [], double_spend_timeout: 1
  test "transaction 0-conf acceptance" do
    {:ok, _inv, stub, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(
        required_confirmations: 0,
        amount: Money.new(1000, :BCH)
      )

    MockTCPClient.response(@client, FloweeFixtures.tx_seen())
    HandlerSubscriberCollector.await_status(stub, :paid)

    assert [
             {:invoice_status, :open, _},
             {:invoice_status, :processing, _},
             {:invoice_status, :paid, _}
           ] = HandlerSubscriberCollector.received(stub)
  end

  @tag backends: []
  test "transaction confirmation acceptance" do
    {:ok, _inv, stub, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(
        required_confirmations: 1,
        amount: Money.new(1000, :BCH)
      )

    MockTCPClient.response(@client, FloweeFixtures.tx_1_conf())
    MockTCPClient.response(@client, FloweeFixtures.new_block())
    HandlerSubscriberCollector.await_status(stub, :paid)

    assert [
             {:invoice_status, :open, _},
             {:invoice_status, :processing, _},
             {:invoice_status, :paid, _}
           ] = HandlerSubscriberCollector.received(stub)
  end

  @tag backends: [], double_spend_timeout: 1
  test "single tx 0-conf to multiple monitored addresses" do
    {:ok, _invoice, stub1, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(
        required_confirmations: 0,
        amount: Money.new(10_000, :BCH),
        address: {"bitcoincash:qrwjyrzae2av8wxvt79e2ukwl9q58m3u6cwn8k2dpa", -1}
      )

    {:ok, _invoice, stub2, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(
        required_confirmations: 0,
        amount: Money.new(20_000, :BCH),
        address: {"bitcoincash:qz96wvrhsrg9j3rnczg7jkh3dlgshtcxzu89qrrcgc", -2}
      )

    MockTCPClient.response(@client, FloweeFixtures.multi_tx_seen())
    HandlerSubscriberCollector.await_status(stub1, :paid)
    HandlerSubscriberCollector.await_status(stub2, :paid)

    assert [
             {:invoice_status, :open, _},
             {:invoice_status, :processing, _},
             {:invoice_status, :paid, _}
           ] = HandlerSubscriberCollector.received(stub1)

    assert [
             {:invoice_status, :open, _},
             {:invoice_status, :processing, _},
             {:invoice_status, :paid, _}
           ] = HandlerSubscriberCollector.received(stub2)
  end

  @tag backends: [], double_spend_timeout: 1
  test "multiple tx 0-conf to multiple monitored addresses" do
    {:ok, _invoice, stub1, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(
        required_confirmations: 0,
        amount: Money.new(15_000, :BCH),
        address: {"bitcoincash:qrwjyrzae2av8wxvt79e2ukwl9q58m3u6cwn8k2dpa", -1}
      )

    {:ok, _invoice, stub2, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(
        required_confirmations: 0,
        amount: Money.new(20_000, :BCH),
        address: {"bitcoincash:qz96wvrhsrg9j3rnczg7jkh3dlgshtcxzu89qrrcgc", -2}
      )

    # Give 10000 to the first one, and 20000 to the second one
    MockTCPClient.response(@client, FloweeFixtures.multi_tx_seen())

    # Give 5000 to the first one.
    MockTCPClient.response(@client, FloweeFixtures.multi_tx_a_seen())

    HandlerSubscriberCollector.await_status(stub1, :paid)
    HandlerSubscriberCollector.await_status(stub2, :paid)

    assert [
             {:invoice_status, :open, _},
             {:invoice_status, :processing, _},
             {:invoice_status, :paid, _}
           ] = HandlerSubscriberCollector.received(stub1)

    assert [
             {:invoice_status, :open, _},
             {:invoice_status, :processing, _},
             {:invoice_status, :paid, _}
           ] = HandlerSubscriberCollector.received(stub2)
  end

  @tag backends: [], double_spend_timeout: 1
  test "single tx 1-conf to multiple monitored addresses" do
    {:ok, _invoice, stub1, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(
        required_confirmations: 1,
        amount: Money.new(10_000, :BCH),
        address: {"bitcoincash:qrwjyrzae2av8wxvt79e2ukwl9q58m3u6cwn8k2dpa", -1}
      )

    {:ok, _invoice, stub2, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(
        required_confirmations: 1,
        amount: Money.new(20_000, :BCH),
        address: {"bitcoincash:qz96wvrhsrg9j3rnczg7jkh3dlgshtcxzu89qrrcgc", -2}
      )

    MockTCPClient.response(@client, FloweeFixtures.multi_tx_seen())

    HandlerSubscriberCollector.await_status(stub1, :processing)
    HandlerSubscriberCollector.await_status(stub2, :processing)

    assert [
             {:invoice_status, :open, _},
             {:invoice_status, :processing, _}
           ] = HandlerSubscriberCollector.received(stub1)

    assert [
             {:invoice_status, :open, _},
             {:invoice_status, :processing, _}
           ] = HandlerSubscriberCollector.received(stub2)

    MockTCPClient.response(@client, FloweeFixtures.multi_tx_1_conf())
    # Manually set blocks to avoid having to find fixtures for all things
    Blocks.new_block(:BCH, 690_933)

    HandlerSubscriberCollector.await_status(stub1, :paid)
    HandlerSubscriberCollector.await_status(stub2, :paid)

    assert [
             {:invoice_status, :open, _},
             {:invoice_status, :processing, _},
             {:invoice_status, :paid, _}
           ] = HandlerSubscriberCollector.received(stub1)

    assert [
             {:invoice_status, :open, _},
             {:invoice_status, :processing, _},
             {:invoice_status, :paid, _}
           ] = HandlerSubscriberCollector.received(stub2)
  end

  @tag backends: [], double_spend_timeout: 1
  test "multiple tx 1-conf to multiple monitored addresses" do
    {:ok, _invoice, stub1, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(
        required_confirmations: 1,
        amount: Money.new(15_000, :BCH),
        address: {"bitcoincash:qrwjyrzae2av8wxvt79e2ukwl9q58m3u6cwn8k2dpa", 0}
      )

    {:ok, _invoice, stub2, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(
        required_confirmations: 1,
        amount: Money.new(20_000, :BCH),
        address: {"bitcoincash:qz96wvrhsrg9j3rnczg7jkh3dlgshtcxzu89qrrcgc", 1}
      )

    # Give 10000 to the first one, and 20000 to the second one
    MockTCPClient.response(@client, FloweeFixtures.multi_tx_seen())

    # Confirm the first transaction.
    MockTCPClient.response(@client, FloweeFixtures.multi_tx_1_conf())
    # Manually set blocks to avoid having to find fixtures for all things
    Blocks.new_block(:BCH, 690_933)

    HandlerSubscriberCollector.await_status(stub1, :open)
    HandlerSubscriberCollector.await_status(stub2, :paid)

    assert [
             {:invoice_status, :open, _}
           ] = HandlerSubscriberCollector.received(stub1)

    assert [
             {:invoice_status, :open, _},
             {:invoice_status, :processing, _},
             {:invoice_status, :paid, _}
           ] = HandlerSubscriberCollector.received(stub2)

    # Give 5000 to the first one.
    MockTCPClient.response(@client, FloweeFixtures.multi_tx_a_seen())

    # And confirm.
    MockTCPClient.response(@client, FloweeFixtures.multi_tx_a_1_conf())
    # Manually set blocks to avoid having to find fixtures for all things
    Blocks.new_block(:BCH, 690_934)

    HandlerSubscriberCollector.await_status(stub1, :paid)

    assert [
             {:invoice_status, :open, _},
             {:invoice_status, :processing, _},
             {:invoice_status, :paid, _}
           ] = HandlerSubscriberCollector.received(stub1)
  end

  @tag backends: [], init_message: false
  test "wait for Flowee to become ready" do
    # Send it an incomplete startup message to get it going.
    MockTCPClient.response(@client, FloweeFixtures.blockchain_verifying_info())

    # Wait a bit to let it act.
    :timer.sleep(10)

    # It should not be ready yet, Flowee is still preparing.
    assert BitPal.Backend.Flowee.ready?(BitPal.Backend.Flowee) == false

    # Give it a new message, now it should be done!
    MockTCPClient.response(@client, FloweeFixtures.blockchain_info())
    assert eventually(fn -> BitPal.Backend.Flowee.ready?(BitPal.Backend.Flowee) end)
  end

  @tag backends: [], init_message: false
  test "make sure recovery works" do
    # Simulate the state stored in the DB:
    {:ok, _invoice, stub1, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(
        required_confirmations: 1,
        amount: Money.new(15_000, :BCH),
        address: {"bitcoincash:qrwjyrzae2av8wxvt79e2ukwl9q58m3u6cwn8k2dpa", 0}
      )

    {:ok, _invoice, stub2, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(
        required_confirmations: 1,
        amount: Money.new(20_000, :BCH),
        address: {"bitcoincash:qz96wvrhsrg9j3rnczg7jkh3dlgshtcxzu89qrrcgc", 1}
      )

    # We are now at height 690933:
    Blocks.set_block_height(:BCH, 690_932)

    # Now, we tell Flowee the current block height. It will try to recover, and ask for the missing
    # block.
    MockTCPClient.response(@client, FloweeFixtures.blockchain_info_690933())

    # Note: The addresses may be in any order, so we check for both of them.
    assert eventually(fn ->
             last = MockTCPClient.last_sent(@client)

             last == FloweeFixtures.block_info_query_690933_a() ||
               last == FloweeFixtures.block_info_query_690933_a()
           end)

    # At this point, Flowee should not report being ready.
    assert BitPal.Backend.Flowee.ready?(BitPal.Backend.Flowee) == false

    # Tell it what happened:
    MockTCPClient.response(@client, FloweeFixtures.block_info_690933())

    # It will ask for block info again, so that it can properly capture if Flowee managed to find
    # another block while it updated the last block. At this point, it should be happy.
    MockTCPClient.response(@client, FloweeFixtures.blockchain_info_690933())

    # Both should be paid by now.
    HandlerSubscriberCollector.await_status(stub1, :paid)
    HandlerSubscriberCollector.await_status(stub2, :paid)

    # It should also be ready now.
    assert BitPal.Backend.Flowee.ready?(BitPal.Backend.Flowee) == true
  end

  # Things we need to test:
  #
  # version
  # double spend
end
