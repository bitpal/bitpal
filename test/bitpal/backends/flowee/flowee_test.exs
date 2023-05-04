defmodule BitPal.Backend.FloweeTest do
  use ExUnit.Case, async: false
  use BitPal.CaseHelpers
  import Mox
  import BitPal.MockTCPClient
  alias BitPal.Backend.FloweeFixtures
  alias BitPal.BackendEvents
  alias BitPal.BackendManager
  alias BitPal.Blocks
  alias BitPal.HandlerSubscriberCollector
  alias BitPal.IntegrationCase
  alias BitPal.MockTCPClient

  @currency :BCH
  @xpub Application.compile_env!(:bitpal, [:BCH, :xpub])
  @client BitPal.FloweeMock

  setup :set_mox_from_context

  setup tags do
    init_mock(@client)

    # Some tests don't want to have the initialization automatically enabled.
    if Map.get(tags, :init_message, true) do
      MockTCPClient.response(@client, FloweeFixtures.blockchain_info_reply())
    end

    backends = [
      {BitPal.Backend.Flowee,
       tcp_client: @client, ping_timeout: tags[:ping_timeout] || :timer.minutes(1)}
    ]

    IntegrationCase.setup_integration(local_manager: true, backends: backends, async: false)
    |> Map.put(:store, create_store())
  end

  defp test_invoice(params) do
    params
    |> Enum.into(%{
      address_key: @xpub,
      price: Money.parse!(Keyword.fetch!(params, :amount), @currency)
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

  test "transaction 0-conf acceptance", %{store: store, manager: manager} do
    {:ok, _inv, stub, _invoice_handler} =
      test_invoice(
        store: store,
        required_confirmations: 0,
        amount: 0.000_01,
        double_spend_timeout: 1,
        manager: manager
      )

    MockTCPClient.response(@client, FloweeFixtures.tx_seen())
    HandlerSubscriberCollector.await_msg(stub, {:invoice, :paid})

    assert [
             {{:invoice, :finalized}, _},
             {{:invoice, :processing}, _},
             {{:invoice, :paid}, _}
           ] = HandlerSubscriberCollector.received(stub)
  end

  test "transaction confirmation acceptance", %{store: store} do
    {:ok, _inv, stub, _invoice_handler} =
      test_invoice(
        store: store,
        required_confirmations: 1,
        amount: 0.000_01
      )

    MockTCPClient.response(@client, FloweeFixtures.tx_1_conf())
    MockTCPClient.response(@client, FloweeFixtures.new_block())
    HandlerSubscriberCollector.await_msg(stub, {:invoice, :paid})

    assert [
             {{:invoice, :finalized}, _},
             {{:invoice, :processing}, _},
             {{:invoice, :paid}, _}
           ] = HandlerSubscriberCollector.received(stub)
  end

  test "single tx 0-conf to multiple monitored addresses", %{store: store} do
    {:ok, _invoice, stub1, _invoice_handler} =
      test_invoice(
        store: store,
        double_spend_timeout: 1,
        required_confirmations: 0,
        amount: 0.000_1,
        address_id: "bitcoincash:qrwjyrzae2av8wxvt79e2ukwl9q58m3u6cwn8k2dpa"
      )

    {:ok, _invoice, stub2, _invoice_handler} =
      test_invoice(
        store: store,
        double_spend_timeout: 1,
        required_confirmations: 0,
        amount: 0.000_2,
        address_id: "bitcoincash:qz96wvrhsrg9j3rnczg7jkh3dlgshtcxzu89qrrcgc"
      )

    MockTCPClient.response(@client, FloweeFixtures.multi_tx_seen())
    HandlerSubscriberCollector.await_msg(stub1, {:invoice, :paid})
    HandlerSubscriberCollector.await_msg(stub2, {:invoice, :paid})

    assert [
             {{:invoice, :finalized}, _},
             {{:invoice, :processing}, _},
             {{:invoice, :paid}, _}
           ] = HandlerSubscriberCollector.received(stub1)

    assert [
             {{:invoice, :finalized}, _},
             {{:invoice, :processing}, _},
             {{:invoice, :paid}, _}
           ] = HandlerSubscriberCollector.received(stub2)
  end

  @tag double_spend_timeout: 1
  test "multiple tx 0-conf to multiple monitored addresses", %{store: store} do
    {:ok, _invoice, stub1, _invoice_handler} =
      test_invoice(
        store: store,
        double_spend_timeout: 1,
        required_confirmations: 0,
        amount: 0.000_15,
        address_id: "bitcoincash:qrwjyrzae2av8wxvt79e2ukwl9q58m3u6cwn8k2dpa"
      )

    {:ok, _invoice, stub2, _invoice_handler} =
      test_invoice(
        store: store,
        double_spend_timeout: 1,
        required_confirmations: 0,
        amount: 0.000_2,
        address_id: "bitcoincash:qz96wvrhsrg9j3rnczg7jkh3dlgshtcxzu89qrrcgc"
      )

    # Give 10000 to the first one, and 20000 to the second one
    MockTCPClient.response(@client, FloweeFixtures.multi_tx_seen())

    # There's a race condition here where we might store the txs in the db
    # at the same time, causing us to miss the `invoice_underpaid` event.
    # This has no importance in the real world, but may screw up the test if
    # we don't have this wait between.
    HandlerSubscriberCollector.await_msg(stub2, {:invoice, :paid})

    # Give 5000 to the first one.
    MockTCPClient.response(@client, FloweeFixtures.multi_tx_a_seen())

    HandlerSubscriberCollector.await_msg(stub1, {:invoice, :paid})

    assert [
             {{:invoice, :finalized}, _},
             {{:invoice, :underpaid}, _},
             {{:invoice, :processing}, _},
             {{:invoice, :paid}, _}
           ] = HandlerSubscriberCollector.received(stub1)

    assert [
             {{:invoice, :finalized}, _},
             {{:invoice, :processing}, _},
             {{:invoice, :paid}, _}
           ] = HandlerSubscriberCollector.received(stub2)
  end

  @tag double_spend_timeout: 1
  test "single tx 1-conf to multiple monitored addresses", %{store: store} do
    {:ok, _invoice, stub1, _invoice_handler} =
      test_invoice(
        store: store,
        double_spend_timeout: 1,
        required_confirmations: 1,
        amount: 0.000_1,
        address_id: "bitcoincash:qrwjyrzae2av8wxvt79e2ukwl9q58m3u6cwn8k2dpa"
      )

    {:ok, _invoice, stub2, _invoice_handler} =
      test_invoice(
        store: store,
        double_spend_timeout: 1,
        required_confirmations: 1,
        amount: 0.000_2,
        address_id: "bitcoincash:qz96wvrhsrg9j3rnczg7jkh3dlgshtcxzu89qrrcgc"
      )

    MockTCPClient.response(@client, FloweeFixtures.multi_tx_seen())

    HandlerSubscriberCollector.await_msg(stub1, {:invoice, :processing})
    HandlerSubscriberCollector.await_msg(stub2, {:invoice, :processing})

    assert [
             {{:invoice, :finalized}, _},
             {{:invoice, :processing}, _}
           ] = HandlerSubscriberCollector.received(stub1)

    assert [
             {{:invoice, :finalized}, _},
             {{:invoice, :processing}, _}
           ] = HandlerSubscriberCollector.received(stub2)

    MockTCPClient.response(@client, FloweeFixtures.multi_tx_1_conf())
    # Manually set blocks to avoid having to find fixtures for all things
    Blocks.new_block(@currency, 690_933)

    HandlerSubscriberCollector.await_msg(stub1, {:invoice, :paid})
    HandlerSubscriberCollector.await_msg(stub2, {:invoice, :paid})

    assert [
             {{:invoice, :finalized}, _},
             {{:invoice, :processing}, _},
             {{:invoice, :paid}, _}
           ] = HandlerSubscriberCollector.received(stub1)

    assert [
             {{:invoice, :finalized}, _},
             {{:invoice, :processing}, _},
             {{:invoice, :paid}, _}
           ] = HandlerSubscriberCollector.received(stub2)
  end

  @tag double_spend_timeout: 1
  test "multiple tx 1-conf to multiple monitored addresses", %{store: store} do
    {:ok, _invoice, stub1, _invoice_handler} =
      test_invoice(
        store: store,
        double_spend_timeout: 1,
        required_confirmations: 1,
        amount: 0.000_15,
        address_id: "bitcoincash:qrwjyrzae2av8wxvt79e2ukwl9q58m3u6cwn8k2dpa"
      )

    {:ok, _invoice, stub2, _invoice_handler} =
      test_invoice(
        store: store,
        double_spend_timeout: 1,
        required_confirmations: 1,
        amount: 0.000_2,
        address_id: "bitcoincash:qz96wvrhsrg9j3rnczg7jkh3dlgshtcxzu89qrrcgc"
      )

    # Give 10000 to the first one, and 20000 to the second one
    MockTCPClient.response(@client, FloweeFixtures.multi_tx_seen())

    # Confirm the first transaction.
    MockTCPClient.response(@client, FloweeFixtures.multi_tx_1_conf())
    # Manually set blocks to avoid having to find fixtures for all things
    Blocks.new_block(@currency, 690_933)

    HandlerSubscriberCollector.await_msg(stub1, {:invoice, :finalized})
    HandlerSubscriberCollector.await_msg(stub2, {:invoice, :paid})

    assert [
             {{:invoice, :finalized}, _},
             {{:invoice, :underpaid}, _}
           ] = HandlerSubscriberCollector.received(stub1)

    assert [
             {{:invoice, :finalized}, _},
             {{:invoice, :processing}, _},
             {{:invoice, :paid}, _}
           ] = HandlerSubscriberCollector.received(stub2)

    # Give 5000 to the first one.
    MockTCPClient.response(@client, FloweeFixtures.multi_tx_a_seen())

    # And confirm.
    MockTCPClient.response(@client, FloweeFixtures.multi_tx_a_1_conf())
    # Manually set blocks to avoid having to find fixtures for all things
    Blocks.new_block(@currency, 690_934)

    HandlerSubscriberCollector.await_msg(stub1, {:invoice, :paid})

    assert [
             {{:invoice, :finalized}, _},
             {{:invoice, :underpaid}, _},
             {{:invoice, :processing}, _},
             {{:invoice, :paid}, _}
           ] = HandlerSubscriberCollector.received(stub1)
  end

  @tag init_message: false
  test "wait for Flowee to become ready" do
    # Send it an incomplete startup message to get it going.
    MockTCPClient.response(@client, FloweeFixtures.blockchain_verifying_info_reply())

    # Wait a bit to let it act.
    :timer.sleep(10)

    # It should not be ready yet, Flowee is still preparing.
    assert {:syncing, _} = BackendManager.status(@currency)

    # Give it a new message, now it should be done!
    MockTCPClient.response(@client, FloweeFixtures.blockchain_info_reply())
    assert eventually(fn -> BackendManager.status(@currency) == :ready end)
  end

  @tag init_message: false
  test "make sure recovery works", %{store: store} do
    # During startup it will ask for blockchain info.
    # (Also for the version, but we ignore it here.)
    assert eventually(fn ->
             MockTCPClient.last_sent(@client) == FloweeFixtures.get_blockchain_info()
           end)

    # When an invoice is created, Flowee should subscribe to the addresses.
    {:ok, _invoice, stub1, _invoice_handler} =
      test_invoice(
        store: store,
        required_confirmations: 1,
        amount: 0.000_15,
        address_id: "bitcoincash:qrwjyrzae2av8wxvt79e2ukwl9q58m3u6cwn8k2dpa"
      )

    assert eventually(fn ->
             FloweeFixtures.address_subscribe_1() == MockTCPClient.last_sent(@client)
           end)

    {:ok, _invoice, stub2, _invoice_handler} =
      test_invoice(
        store: store,
        required_confirmations: 1,
        amount: 0.000_2,
        address_id: "bitcoincash:qz96wvrhsrg9j3rnczg7jkh3dlgshtcxzu89qrrcgc"
      )

    assert eventually(fn ->
             FloweeFixtures.address_subscribe_2() == MockTCPClient.last_sent(@client)
           end)

    # Simulate the state stored in the DB:
    # We are now at height 690933, but we have only registered up to 690_931
    Blocks.set_block_height(@currency, 690_931)

    # Now, we tell Flowee the current block height. It will try to recover
    # and ask for the missing blocks.
    MockTCPClient.response(@client, FloweeFixtures.blockchain_info_690933_reply())

    # First it asks for the next block with the hashes of the two above addresses.
    # Note: The addresses may be in any order, so we check for both of them.
    assert eventually(fn ->
             last = MockTCPClient.last_sent(@client)

             last == FloweeFixtures.get_block_690932_1() ||
               last == FloweeFixtures.get_block_690932_2()
           end)

    # At this point, Flowee should not report being ready.
    assert {:recovering, 690_931, 690_933} = BackendManager.status(@currency)

    # Give them an empty block 690932
    MockTCPClient.response(@client, FloweeFixtures.block_info_690932_reply())

    # Then Flowee should ask for block 690933.
    # It should not reuse the existing address hashes but send a special reuse directive.
    assert eventually(fn ->
             MockTCPClient.last_sent(@client) ==
               FloweeFixtures.get_block_690933_reused_hashes()
           end)

    assert {:recovering, 690_932, 690_933} = BackendManager.status(@currency)

    # Give them the block 690933 with transactions.
    MockTCPClient.response(@client, FloweeFixtures.block_info_690933_reply())

    # It will ask for block info again, so that it can properly capture if Flowee managed to find
    # another block while it updated the last block. At this point, it should be happy.
    assert eventually(fn ->
             MockTCPClient.last_sent(@client) == FloweeFixtures.get_blockchain_info()
           end)

    MockTCPClient.response(@client, FloweeFixtures.blockchain_info_690933_reply())

    # Both should be paid by now.
    HandlerSubscriberCollector.await_msg(stub1, {:invoice, :paid})
    HandlerSubscriberCollector.await_msg(stub2, {:invoice, :paid})

    # It should also be ready now.
    assert eventually(fn ->
             BackendManager.status(@currency) == :ready
           end)
  end

  test "restart after closed connection" do
    # Wait for Flowee to be ready
    assert eventually(fn -> BackendManager.status(@currency) == :ready end)

    BackendEvents.subscribe(@currency)

    MockTCPClient.error(@client, :econnerror)
    Process.sleep(10)

    assert_receive {{:backend, :status},
                    %{
                      status: {:stopped, {:shutdown, {:connection, :econnerror}}},
                      currency_id: @currency
                    }}

    assert_receive {{:backend, :status}, %{status: :starting, currency_id: @currency}}
  end

  # Things we need to test:
  #
  # version
  # double spend
  # reorg
end
