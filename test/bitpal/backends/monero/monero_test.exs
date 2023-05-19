defmodule BitPal.Backend.MoneroTest do
  use ExUnit.Case, async: false
  use BitPal.CaseHelpers
  import Mox
  alias BitPal.Backend.Monero
  alias BitPal.Backend.MoneroFixtures
  alias BitPal.BackendManager
  alias BitPal.BackendStatusSupervisor
  alias BitPal.BackendEvents
  alias BitPal.Blocks
  alias BitPal.ExtNotificationHandler
  alias BitPal.HandlerSubscriberCollector
  alias BitPal.IntegrationCase
  alias BitPal.MockRPCClient

  @currency :XMR
  @client BitPal.MoneroMock

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup tags do
    MockRPCClient.init_mock(@client, missing_call_reply: tags[:missing_call_reply])

    BackendEvents.subscribe(@currency)

    if Map.get(tags, :init_backend, true) do
      if Map.get(tags, :init_messages, true) do
        init_messages()
      end

      res = init_backend(tags)

      store = create_store()

      res
      |> Map.put(:store, store)
      |> Map.put(:address_key, get_or_create_address_key(store.id, @currency))
    else
      %{}
    end
  end

  defp init_messages do
    height = 10

    # Yeah it's confusing that we have the same mock function for both wallets and daemons...
    MockRPCClient.expect(@client, "get_version", fn _ ->
      MoneroFixtures.daemon_get_version()
    end)

    MockRPCClient.expect(@client, "get_version", fn _ ->
      MoneroFixtures.wallet_get_version()
    end)

    MockRPCClient.expect(@client, "get_height", fn _ ->
      MoneroFixtures.get_height(height: height)
    end)

    MockRPCClient.expect(@client, "sync_info", fn _ ->
      MoneroFixtures.sync_info(height: height)
    end)

    MockRPCClient.expect(@client, "get_info", fn _ ->
      MoneroFixtures.get_info(height: height)
    end)

    MockRPCClient.stub(@client, "get_transfers", fn _ ->
      MoneroFixtures.get_transfers()
    end)
  end

  defp init_backend(tags) do
    backends = [
      {BitPal.Backend.Monero,
       rpc_client: @client,
       log_level: tags[:log_level] || :all,
       restart: tags[:restart] || :temporary,
       reconnect_timeout: 10,
       sync_check_interval: 10}
    ]

    IntegrationCase.setup_integration(local_manager: true, backends: backends, async: false)
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

  describe "setup and sync" do
    @tag missing_call_reply: {:error, :connerror}, init_backend: false
    test "successful setup with sync reporting" do
      BackendStatusSupervisor.configure_status_handler(@currency, %{rate_limit: 1})

      # Connection with daemon
      MockRPCClient.expect(@client, "get_version", fn _ ->
        MoneroFixtures.daemon_get_version()
      end)

      # Connection with wallet
      MockRPCClient.expect(@client, "get_version", fn _ ->
        MoneroFixtures.wallet_get_version()
      end)

      # Initial sync request
      MockRPCClient.expect(@client, "get_height", fn _ ->
        MoneroFixtures.get_height(height: 10)
      end)

      MockRPCClient.expect(@client, "sync_info", fn _ ->
        MoneroFixtures.sync_info(height: 10, target_height: 20)
      end)

      # Daemon has synced, but not the wallet
      MockRPCClient.expect(@client, "get_height", fn _ ->
        MoneroFixtures.get_height(height: 15)
      end)

      MockRPCClient.expect(@client, "sync_info", fn _ ->
        MoneroFixtures.sync_info(height: 20, target_height: 0)
      end)

      # Wallet has also synced
      MockRPCClient.expect(@client, "get_height", fn _ ->
        MoneroFixtures.get_height(height: 20)
      end)

      MockRPCClient.expect(@client, "sync_info", fn _ ->
        MoneroFixtures.sync_info(height: 20, target_height: 0)
      end)

      MockRPCClient.stub(@client, "get_transfers", fn _ ->
        MoneroFixtures.get_transfers()
      end)

      MockRPCClient.expect(@client, "get_info", fn _ ->
        MoneroFixtures.get_info(height: 21)
      end)

      init_backend(%{})

      assert_receive {{:backend, :status}, %{status: :starting}}
      assert_receive {{:backend, :status}, %{status: {:syncing, {10, 20}}}}
      assert_receive {{:backend, :status}, %{status: {:syncing, {15, 20}}}}
      assert_receive {{:backend, :status}, %{status: :ready}}

      # Sets block height from get_info
      eventually(fn ->
        Blocks.fetch_height(@currency) == {:ok, 21}
      end)
    end

    @tag missing_call_reply: {:error, :connerror}, init_messages: false
    test "stops after init if we can't connect" do
      assert eventually(fn ->
               BackendManager.status(@currency) == {:stopped, {:shutdown, :connerror}}
             end)
    end

    @tag restart: :transient, log_level: :critical
    test "restart after closed connection" do
      assert eventually(fn ->
               BackendManager.status(@currency) == :ready
             end)

      MockRPCClient.expect(@client, "get_info", fn _ ->
        {:error, :econnerror}
      end)

      init_messages()

      send(ExtNotificationHandler, {:notify, ["monero:block-notify", "block-id"], 0})

      assert_receive {{:backend, :status},
                      %{
                        status: {:stopped, {:error, :unknown}},
                        currency_id: @currency
                      }}

      assert_receive {{:backend, :status}, %{status: :starting, currency_id: @currency}}
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

      {:ok, inv, stub, _handler} =
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

      MockRPCClient.expect(@client, "get_transfers", fn %{
                                                          account_index: 0,
                                                          subaddr_indices: _indices
                                                        } ->
        MoneroFixtures.get_transfers([
          %{txid: txid, address: inv.address_id, amount: amount, height: 11}
        ])
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
  # - recovery
  # - reorgs
  # - regular saving of wallet
end
