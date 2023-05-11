defmodule BitPal.Backend.MoneroTest do
  use ExUnit.Case, async: false
  use BitPal.CaseHelpers
  import Mox
  alias BitPal.MockRPCClient
  alias BitPal.Backend.Monero
  alias BitPal.Backend.MoneroFixtures
  alias BitPal.IntegrationCase
  alias BitPal.HandlerSubscriberCollector
  alias BitPal.ExtNotificationHandler

  @currency :XMR
  @client BitPal.MoneroMock

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup _tags do
    MockRPCClient.init_mock(@client)

    MockRPCClient.expect(@client, "get_info", fn _ ->
      MoneroFixtures.get_info()
    end)

    backends = [
      {BitPal.Backend.Monero, rpc_client: @client, log_level: :all, restart: :temporary}
    ]

    res = IntegrationCase.setup_integration(local_manager: true, backends: backends, async: false)

    store = create_store()

    res
    |> Map.put(:store, store)
    |> Map.put(:address_key, get_or_create_address_key(store.id, @currency))
  end

  defp test_invoice(params) do
    params =
      Enum.into(params, %{
        payment_currency_id: @currency,
        status: :draft
      })

    if params.status != :draft do
      MockRPCClient.expect(@client, "create_address", fn %{account_index: 0} ->
        MoneroFixtures.create_address(1)
      end)
    end

    if params.status == :draft do
      create_invoice(params)
    else
      HandlerSubscriberCollector.create_invoice(params)
    end
  end

  describe "assign_address" do
    test "assigns a new address", %{store: store} do
      invoice = test_invoice(store: store)

      MockRPCClient.expect(@client, "create_address", fn %{account_index: 0} ->
        MoneroFixtures.create_address(1)
      end)

      assert invoice.address_id == nil
      {:ok, invoice} = Monero.assign_address(Monero, invoice)
      assert invoice.address_id != nil
    end

    test "assigns new subaddresses", %{store: store} do
      for i <- 1..4 do
        MockRPCClient.expect(@client, "create_address", fn %{account_index: 0} ->
          MoneroFixtures.create_address(i)
        end)

        invoice = test_invoice(store: store)
        {:ok, invoice} = Monero.assign_address(Monero, invoice)
        assert invoice.address_id != nil
        assert invoice.address.address_index == i
      end
    end
  end

  describe "transaction acceptance" do
    @tag skip: true
    test "0-conf acceptance", %{store: store, manager: manager} do
      {:ok, _inv, stub, _handler} =
        test_invoice(
          store: store,
          required_confirmations: 0,
          amount: 0.1,
          double_spend_timeout: 1,
          status: :open,
          manager: manager
        )

      txid = MoneroFixtures.txid()

      MockRPCClient.expect(@client, "get_transfer_by_txid", fn %{txid: ^txid, account_index: 0} ->
        MoneroFixtures.get_transfer_by_txid()
      end)

      send(ExtNotificationHandler, {:notify, ["monero:tx-notify", txid], 0})

      HandlerSubscriberCollector.await_msg(stub, {:invoice, :paid})

      assert [
               {{:invoice, :finalized}, _},
               {{:invoice, :processing}, _},
               {{:invoice, :paid}, _}
             ] = HandlerSubscriberCollector.received(stub)
    end

    @tag skip: true
    test "confirmation acceptance, confirmed at first sight", %{store: store, manager: manager} do
      {:ok, _inv, stub, _handler} =
        test_invoice(
          store: store,
          required_confirmations: 1,
          amount: 0.1,
          status: :open,
          manager: manager
        )

      txid = MoneroFixtures.txid()

      # First we see an unconfirmed tx
      MockRPCClient.expect(@client, "get_transfer_by_txid", fn %{txid: ^txid, account_index: 0} ->
        MoneroFixtures.get_transfer_by_txid()
      end)

      send(ExtNotificationHandler, {:notify, ["monero:tx-notify", txid], 0})

      HandlerSubscriberCollector.await_msg(stub, {:invoice, :paid})

      assert [
               {{:invoice, :finalized}, _},
               {{:invoice, :processing}, _},
               {{:invoice, :paid}, _}
             ] = HandlerSubscriberCollector.received(stub)
    end

    test "confirmation acceptance, multiple confirmations", %{store: store, manager: manager} do
    end

    test "confirmation acceptance, seen first then marks as confirmed", %{
      store: store,
      manager: manager
    } do
    end
  end

  # When tx-notify:
  # - Update tx
  #
  # When block-notify:
  # - poll info, updates transactions
  #
  # When reorg-notify:
  # - fetch all txs with affected heights
  # - recheck them
  #
  # Poll info
  # - Update block height
  #   If new unseen height, update similar to block-notify
  #   - get_transfers
  #     update all transactions seen there
  #
  # When we see a new block, save the wallet

  # test "transaction 0-conf acceptance", %{store: store, manager: manager} do
  # end
  #
  # test "transaction confirmation acceptance", %{store: store} do
  # end
  #
  # @tag init_message: false
  # test "wait for daemon to become ready" do
  # end
  #
  # @tag init_message: false
  # test "make sure recovery works", %{store: store} do
  # end
  #
  # test "restart after closed connection" do
  # end
  #
  # test "handle reorg" do
  # end
  #
  # test "handle double spend" do
  # end
  #
  # test "updates info" do
  # end
end
