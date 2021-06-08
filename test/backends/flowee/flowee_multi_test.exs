defmodule BitPal.Backend.FloweeMultiTest do
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
end
