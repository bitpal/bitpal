defmodule BitPal.Backend.FloweeTest do
  use BitPal.IntegrationCase
  import Mox
  import BitPal.MockTCPClient
  alias BitPal.Backend.FloweeFixtures
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
    assert TransactionsOld.get_height() == 687_691

    MockTCPClient.response(@client, FloweeFixtures.new_block())

    assert eventually(fn -> TransactionsOld.get_height() == 687_692 end)
  end

  @tag backends: [], double_spend_timeout: 1
  test "transaction 0-conf acceptance" do
    {:ok, _inv, stub, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(
        required_confirmations: 0,
        amount: Money.new(1000, :BCH)
      )

    MockTCPClient.response(@client, FloweeFixtures.tx_seen())
    HandlerSubscriberCollector.await_state(stub, :accepted)

    assert [
             {:state, :wait_for_tx, _},
             {:state, :wait_for_verification},
             {:state, :accepted}
           ] = HandlerSubscriberCollector.received(stub)
  end

  @tag backends: [], do: true
  test "transaction confirmation acceptance" do
    {:ok, _inv, stub, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(
        required_confirmations: 1,
        amount: Money.new(1000, :BCH)
      )

    MockTCPClient.response(@client, FloweeFixtures.tx_1_conf())
    HandlerSubscriberCollector.await_state(stub, :accepted)

    assert [
             {:state, :wait_for_tx, _},
             {:confirmations, 1},
             {:state, :accepted}
           ] = HandlerSubscriberCollector.received(stub)
  end

  # Things we need to test:
  #
  # version
  # double spend
end
