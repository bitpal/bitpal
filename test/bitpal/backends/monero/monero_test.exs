defmodule BitPal.Backend.MoneroTest do
  use ExUnit.Case, async: false
  use BitPal.CaseHelpers
  import Mox
  alias BitPal.Backend.Monero
  alias BitPal.Backend.MoneroFixtures
  alias BitPal.Blocks
  alias BitPal.ExtNotificationHandler
  alias BitPal.HandlerSubscriberCollector
  alias BitPal.IntegrationCase
  alias BitPal.MockRPCClient

  @currency :XMR
  @client BitPal.MoneroMock

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup _tags do
    MockRPCClient.init_mock(@client)

    MockRPCClient.expect(@client, "get_info", fn _ ->
      MoneroFixtures.get_info(height: 10)
    end)

    backends = [
      {BitPal.Backend.Monero, rpc_client: @client, log_level: :all, restart: :temporary}
    ]

    res = IntegrationCase.setup_integration(local_manager: true, backends: backends, async: false)

    eventually(fn ->
      Blocks.fetch_height(@currency) == {:ok, 10}
    end)

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

  describe "blocks" do
    test "increase block height" do
      assert eventually(fn ->
               Blocks.fetch_height(@currency) == {:ok, 10}
             end)

      MockRPCClient.expect(@client, "get_info", fn _ ->
        MoneroFixtures.get_info(height: 11)
      end)

      send(ExtNotificationHandler, {:notify, ["monero:block-notify", "block-id"], 0})

      assert eventually(fn ->
               Blocks.fetch_height(@currency) == {:ok, 11}
             end)
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
    test "0-conf acceptance", %{store: store, manager: manager} do
      amount = 123_000_000

      {:ok, _inv, stub, _handler} =
        test_invoice(
          store: store,
          required_confirmations: 0,
          price: Money.new(amount, :XMR),
          double_spend_timeout: 1,
          status: :open,
          manager: manager
        )

      txid = MoneroFixtures.txid()

      MockRPCClient.expect(@client, "get_transfer_by_txid", fn %{txid: ^txid, account_index: 0} ->
        MoneroFixtures.get_transfer_by_txid(height: 0, amount: amount)
      end)

      send(ExtNotificationHandler, {:notify, ["monero:tx-notify", txid], 0})

      HandlerSubscriberCollector.await_msg(stub, {:invoice, :paid})

      assert [
               {{:invoice, :finalized}, _},
               {{:invoice, :processing}, _},
               {{:invoice, :paid}, _}
             ] = HandlerSubscriberCollector.received(stub)
    end

    test "confirmation acceptance, confirmed at first sight", %{store: store, manager: manager} do
      amount = 123_000_000

      {:ok, _inv, stub, _handler} =
        test_invoice(
          store: store,
          required_confirmations: 1,
          price: Money.new(amount, :XMR),
          status: :open,
          manager: manager
        )

      txid = MoneroFixtures.txid()

      MockRPCClient.expect(@client, "get_transfer_by_txid", fn %{txid: ^txid, account_index: 0} ->
        MoneroFixtures.get_transfer_by_txid(height: 10, amount: amount)
      end)

      send(ExtNotificationHandler, {:notify, ["monero:tx-notify", txid], 0})

      HandlerSubscriberCollector.await_msg(stub, {:invoice, :paid})

      assert [
               {{:invoice, :finalized}, _},
               {{:invoice, :processing}, _},
               {{:invoice, :paid}, _}
             ] = HandlerSubscriberCollector.received(stub)
    end

    test "confirmation acceptance, seen first then multiple confirmations", %{
      store: store,
      manager: manager
    } do
      amount = 123_000_000

      {:ok, _inv, stub, _handler} =
        test_invoice(
          store: store,
          required_confirmations: 3,
          price: Money.new(amount, :XMR),
          status: :open,
          manager: manager
        )

      txid = MoneroFixtures.txid()

      # First we see an unconfirmed tx

      MockRPCClient.expect(@client, "get_transfer_by_txid", fn %{txid: ^txid, account_index: 0} ->
        MoneroFixtures.get_transfer_by_txid(amount: amount, height: 0)
      end)

      send(ExtNotificationHandler, {:notify, ["monero:tx-notify", txid], 0})

      # Then issue block and mark tx as included in the block

      MockRPCClient.expect(@client, "get_info", fn _ ->
        MoneroFixtures.get_info(height: 11)
      end)

      MockRPCClient.expect(@client, "get_transfer_by_txid", fn %{txid: ^txid, account_index: 0} ->
        MoneroFixtures.get_transfer_by_txid(amount: amount, height: 11)
      end)

      send(ExtNotificationHandler, {:notify, ["monero:block-notify", "b0"], 0})

      # Then more blocks

      MockRPCClient.expect(@client, "get_info", fn _ ->
        MoneroFixtures.get_info(height: 12)
      end)

      send(ExtNotificationHandler, {:notify, ["monero:block-notify", "b1"], 0})

      MockRPCClient.expect(@client, "get_info", fn _ ->
        MoneroFixtures.get_info(height: 13)
      end)

      send(ExtNotificationHandler, {:notify, ["monero:block-notify", "b2"], 0})

      HandlerSubscriberCollector.await_msg(stub, {:invoice, :paid})

      assert [
               {{:invoice, :finalized}, _},
               {{:invoice, :processing}, %{confirmations_due: 3}},
               {{:invoice, :processing}, %{confirmations_due: 2}},
               {{:invoice, :processing}, %{confirmations_due: 1}},
               {{:invoice, :paid}, _}
             ] = HandlerSubscriberCollector.received(stub)
    end
  end

  # TODO
  # - initial sync 
  # - recovery
  # - reorgs
  # - regular saving of wallet

  # When reorg-notify:
  # - fetch all txs with affected heights
  # - recheck them
  #
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
