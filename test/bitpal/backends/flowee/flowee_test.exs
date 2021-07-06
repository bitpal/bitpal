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

    MockTCPClient.response(@client, FloweeFixtures.blockchain_info())

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
             Blocks.fetch_block_height!(:BCH) == 690_637
           end)

    MockTCPClient.response(@client, FloweeFixtures.new_block())

    assert eventually(fn ->
             Blocks.fetch_block_height!(:BCH) == 690_638
           end)
  end

  @tag backends: [], double_spend_timeout: 1
  test "transaction 0-conf acceptance" do
    {:ok, _inv, stub, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(
        required_confirmations: 0,
        amount: 0.000_01
      )

    MockTCPClient.response(@client, FloweeFixtures.tx_seen())
    HandlerSubscriberCollector.await_msg(stub, :invoice_paid)

    assert [
             {:invoice_finalized, _},
             {:invoice_processing, _},
             {:invoice_paid, _}
           ] = HandlerSubscriberCollector.received(stub)
  end

  @tag backends: []
  test "transaction confirmation acceptance" do
    {:ok, _inv, stub, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(
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

  @tag backends: [], double_spend_timeout: 1
  test "single tx 0-conf to multiple monitored addresses" do
    {:ok, _invoice, stub1, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(
        required_confirmations: 0,
        amount: 0.000_1,
        address: {"bitcoincash:qrwjyrzae2av8wxvt79e2ukwl9q58m3u6cwn8k2dpa", -1}
      )

    {:ok, _invoice, stub2, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(
        required_confirmations: 0,
        amount: 0.000_2,
        address: {"bitcoincash:qz96wvrhsrg9j3rnczg7jkh3dlgshtcxzu89qrrcgc", -2}
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

  @tag backends: [], double_spend_timeout: 1
  test "multiple tx 0-conf to multiple monitored addresses" do
    {:ok, _invoice, stub1, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(
        required_confirmations: 0,
        amount: 0.000_15,
        address: {"bitcoincash:qrwjyrzae2av8wxvt79e2ukwl9q58m3u6cwn8k2dpa", -1}
      )

    {:ok, _invoice, stub2, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(
        required_confirmations: 0,
        amount: 0.000_2,
        address: {"bitcoincash:qz96wvrhsrg9j3rnczg7jkh3dlgshtcxzu89qrrcgc", -2}
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

  @tag backends: [], double_spend_timeout: 1
  test "single tx 1-conf to multiple monitored addresses" do
    {:ok, _invoice, stub1, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(
        required_confirmations: 1,
        amount: 0.000_1,
        address: {"bitcoincash:qrwjyrzae2av8wxvt79e2ukwl9q58m3u6cwn8k2dpa", -1}
      )

    {:ok, _invoice, stub2, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(
        required_confirmations: 1,
        amount: 0.000_2,
        address: {"bitcoincash:qz96wvrhsrg9j3rnczg7jkh3dlgshtcxzu89qrrcgc", -2}
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
    Blocks.new_block(:BCH, 690_933)

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

  @tag backends: [], double_spend_timeout: 1
  test "multiple tx 1-conf to multiple monitored addresses" do
    {:ok, _invoice, stub1, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(
        required_confirmations: 1,
        amount: 0.000_15,
        address: {"bitcoincash:qrwjyrzae2av8wxvt79e2ukwl9q58m3u6cwn8k2dpa", 0}
      )

    {:ok, _invoice, stub2, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(
        required_confirmations: 1,
        amount: 0.000_2,
        address: {"bitcoincash:qz96wvrhsrg9j3rnczg7jkh3dlgshtcxzu89qrrcgc", 1}
      )

    # Give 10000 to the first one, and 20000 to the second one
    MockTCPClient.response(@client, FloweeFixtures.multi_tx_seen())

    # Confirm the first transaction.
    MockTCPClient.response(@client, FloweeFixtures.multi_tx_1_conf())
    # Manually set blocks to avoid having to find fixtures for all things
    Blocks.new_block(:BCH, 690_933)

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
    Blocks.new_block(:BCH, 690_934)

    HandlerSubscriberCollector.await_msg(stub1, :invoice_paid)

    assert [
             {:invoice_finalized, _},
             {:invoice_underpaid, _},
             {:invoice_processing, _},
             {:invoice_paid, _}
           ] = HandlerSubscriberCollector.received(stub1)
  end

  # Things we need to test:
  #
  # version
  # double spend
end
