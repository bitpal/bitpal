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

  # Things we need to test:
  #
  # version
  # double spend
end
