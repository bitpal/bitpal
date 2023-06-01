defmodule BitPal.Backend.MoneroTest do
  use ExUnit.Case, async: false
  use BitPal.CaseHelpers
  import Mox
  alias BitPal.InvoiceEvents
  alias BitPal.Backend.Monero
  alias BitPal.Backend.Monero.Wallet
  alias BitPal.Backend.Monero.Settings
  alias BitPal.Backend.MoneroFixtures
  alias BitPal.BackendManager
  alias BitPal.BackendStatusSupervisor
  alias BitPal.BackendEvents
  alias BitPal.Blocks
  alias BitPal.DataCase
  alias BitPal.ExtNotificationHandler
  alias BitPal.HandlerSubscriberCollector
  alias BitPal.IntegrationCase
  alias BitPal.MockRPCClient
  alias BitPalFactory.CurrencyFactory
  alias BitPalFactory.TransactionFactory

  @currency :XMR
  @client BitPal.MoneroMock

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup tags do
    # So... For some reason on_exit is delayed, which messes up the next tests
    # as there's some handler that hasn't stopped...
    IntegrationCase.remove_invoice_handlers([:XMR])

    BackendEvents.subscribe(@currency)

    MockRPCClient.init_mock(@client, missing_call_reply: tags[:missing_call_reply])

    if Map.get(tags, :init_backend, true) do
      if Map.get(tags, :init_messages, true) do
        node_init_messages(tags)
      end

      if Map.get(tags, :init_wallet_messages, true) do
        wallet_init_messages(tags)
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

  defp node_init_messages(opts \\ []) do
    height = opts[:height] || 10
    block_hash = opts[:block_hash] || CurrencyFactory.unique_block_id()

    MockRPCClient.expect(@client, "get_version", fn _ ->
      MoneroFixtures.daemon_get_version()
    end)

    MockRPCClient.expect(@client, "sync_info", fn _ ->
      MoneroFixtures.sync_info(height: height)
    end)

    MockRPCClient.expect(@client, "get_info", fn _ ->
      MoneroFixtures.get_info(height: height, hash: block_hash)
    end)
  end

  defp wallet_init_messages(opts \\ []) do
    MockRPCClient.expect(@client, "get_version", fn _ ->
      MoneroFixtures.wallet_get_version()
    end)

    MockRPCClient.expect(@client, "get_transfers", fn _ ->
      MoneroFixtures.get_transfers(opts[:txs] || [])
    end)

    # This is a hack to prevent some tests from sometimes
    # needing a response to this.
    MockRPCClient.stub(@client, "get_transfers", fn _ ->
      MoneroFixtures.get_transfers([])
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

    res = IntegrationCase.setup_integration(local_manager: true, backends: backends, async: false)

    if Map.get(tags, :await_ready, true) do
      assert_receive {{:backend, :status}, %{status: :ready}}
    else
      assert eventually(fn -> {:ok, _} = BackendManager.fetch_backend(res.manager, :XMR) end)
    end

    res
  end

  defp test_invoice(params) do
    params =
      Enum.into(params, %{
        payment_currency_id: @currency,
        status: :draft,
        required_confirmations: 1,
        restart: :transient
      })

    if params.status != :draft do
      MockRPCClient.expect(@client, "create_address", fn _key ->
        MoneroFixtures.create_address(Map.take(params, [:address, :index]))
      end)
    end

    if params.status == :draft do
      create_invoice(params)
    else
      HandlerSubscriberCollector.create_invoice(params)
    end
  end

  defp increase_block(opts) do
    height = Keyword.fetch!(opts, :height)
    get_transfers = Keyword.get(opts, :get_transfers, true)

    MockRPCClient.expect(@client, "get_info", fn _ ->
      MoneroFixtures.get_info(height: height)
    end)

    if get_transfers do
      MockRPCClient.expect(@client, "get_transfers", fn _ ->
        MoneroFixtures.get_transfers(opts[:txs] || [])
      end)
    end

    send(
      ExtNotificationHandler,
      {:notify, ["monero:block-notify", CurrencyFactory.unique_block_id()], 0}
    )
  end

  defp notify_tx(opts) do
    opts = Keyword.put_new_lazy(opts, :txid, &TransactionFactory.unique_txid/0)
    txid = Keyword.fetch!(opts, :txid)
    store_id = Keyword.fetch!(opts, :store_id)

    MockRPCClient.expect(@client, "get_transfer_by_txid", fn %{txid: ^txid, account_index: 0} ->
      MoneroFixtures.get_transfer_by_txid(opts)
    end)

    send(ExtNotificationHandler, {:notify, ["monero:tx-notify", txid, "#{store_id}"], 0})

    txid
  end

  describe "setup and sync" do
    @tag init_wallet_messages: false
    @tag missing_call_reply: {:error, :connerror}, init_backend: false
    test "successful setup with sync reporting" do
      BackendStatusSupervisor.configure_status_handler(@currency, %{rate_limit: 1})

      MockRPCClient.expect(@client, "get_version", fn _ ->
        MoneroFixtures.daemon_get_version()
      end)

      MockRPCClient.expect(@client, "sync_info", fn _ ->
        MoneroFixtures.sync_info(height: 10, target_height: 20)
      end)

      MockRPCClient.expect(@client, "sync_info", fn _ ->
        MoneroFixtures.sync_info(height: 15, target_height: 20)
      end)

      MockRPCClient.expect(@client, "sync_info", fn _ ->
        MoneroFixtures.sync_info(height: 20, target_height: 0)
      end)

      MockRPCClient.expect(@client, "get_info", fn _ ->
        MoneroFixtures.get_info(height: 21)
      end)

      init_backend(%{await_ready: false})

      assert_receive {{:backend, :status}, %{status: :starting}}
      assert_receive {{:backend, :status}, %{status: {:syncing, {10, 20}}}}
      assert_receive {{:backend, :status}, %{status: {:syncing, {15, 20}}}}
      assert_receive {{:backend, :status}, %{status: :ready}}

      # Sets block height from get_info
      eventually(fn ->
        Blocks.fetch_height(@currency) == {:ok, 21}
      end)

      MockRPCClient.verify!(@client)
    end

    @tag init_wallet_messages: false, await_ready: false
    @tag missing_call_reply: {:error, :connerror}, init_messages: false
    test "stops after init if we can't connect" do
      assert eventually(fn ->
               BackendManager.status(@currency) == {:stopped, {:shutdown, :connerror}}
             end)

      MockRPCClient.verify!(@client)
    end

    @tag init_wallet_messages: false, await_ready: false
    @tag restart: :transient, log_level: :critical
    test "restart after closed connection" do
      assert eventually(fn ->
               BackendManager.status(@currency) == :ready
             end)

      MockRPCClient.expect(@client, "get_info", fn _ ->
        {:error, :econnerror}
      end)

      node_init_messages()

      send(ExtNotificationHandler, {:notify, ["monero:block-notify", "block-id"], 0})

      assert_receive {{:backend, :status},
                      %{
                        status: {:stopped, {:error, :unknown}}
                      }}

      assert_receive {{:backend, :status}, %{status: :starting}}
      assert_receive {{:backend, :status}, %{status: :ready}}
    end
  end

  describe "blocks" do
    @tag init_wallet_messages: false
    test "increase block height" do
      assert eventually(fn ->
               Blocks.fetch_height(@currency) == {:ok, 10}
             end)

      increase_block(height: 11)

      assert eventually(fn ->
               Blocks.fetch_height(@currency) == {:ok, 11}
             end)
    end
  end

  describe "assign_address" do
    test "assigns a new address", %{store: store} do
      invoice = test_invoice(store: store)

      MockRPCClient.expect(@client, "create_address", fn %{account_index: 0} ->
        MoneroFixtures.create_address()
      end)

      assert invoice.address_id == nil
      {:ok, invoice} = Monero.assign_address(Monero, invoice)
      assert invoice.address_id != nil
    end

    test "assigns new subaddresses", %{store: store} do
      for i <- 1..4 do
        MockRPCClient.expect(@client, "create_address", fn %{account_index: 0} ->
          MoneroFixtures.create_address(index: i)
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
      {:ok, inv, stub, _handler} =
        test_invoice(
          store: store,
          required_confirmations: 0,
          payment_currency: :XMR,
          double_spend_timeout: 1,
          status: :open,
          manager: manager
        )

      txid = TransactionFactory.unique_txid()

      # For checking before accepting 0-conf
      MockRPCClient.expect(@client, "get_transfers", fn %{
                                                          account_index: 0,
                                                          subaddr_indices: _
                                                        } ->
        MoneroFixtures.get_transfers([
          %{
            txid: txid,
            address: inv.address_id,
            amount: inv.expected_payment.amount,
            height: 0
          }
        ])
      end)

      notify_tx(
        txid: txid,
        height: 0,
        amount: inv.expected_payment.amount,
        address: inv.address_id,
        store_id: store.id
      )

      HandlerSubscriberCollector.await_msg(stub, {:invoice, :paid})

      assert [
               {{:invoice, :finalized}, _},
               {{:invoice, :processing}, _},
               {{:invoice, :paid}, _}
             ] = HandlerSubscriberCollector.received(stub)
    end

    test "reject 0-conf after double-check", %{store: store, manager: manager} do
      {:ok, inv, stub, _handler} =
        test_invoice(
          store: store,
          required_confirmations: 0,
          payment_currency: :XMR,
          double_spend_timeout: 1,
          status: :open,
          manager: manager
        )

      txid = TransactionFactory.unique_txid()

      # For checking before accepting 0-conf
      MockRPCClient.expect(@client, "get_transfers", fn %{
                                                          account_index: 0,
                                                          subaddr_indices: [1]
                                                        } ->
        MoneroFixtures.get_transfers([
          %{
            txid: txid,
            address: inv.address_id,
            amount: inv.expected_payment.amount,
            height: 0,
            double_spend: true
          }
        ])
      end)

      notify_tx(
        txid: txid,
        height: 0,
        amount: inv.expected_payment.amount,
        address: inv.address_id,
        store_id: store.id
      )

      HandlerSubscriberCollector.await_msg(stub, {:invoice, :uncollectible})

      assert [
               {{:invoice, :finalized}, _},
               {{:invoice, :processing}, _},
               {{:invoice, :uncollectible}, %{status: {_, :double_spent}}}
             ] = HandlerSubscriberCollector.received(stub)
    end

    test "confirmation acceptance, confirmed at first sight", %{store: store, manager: manager} do
      {:ok, inv, stub, _handler} =
        test_invoice(
          store: store,
          required_confirmations: 1,
          payment_currency: :XMR,
          status: :open,
          manager: manager
        )

      notify_tx(
        height: 10,
        amount: inv.expected_payment.amount,
        address: inv.address_id,
        store_id: store.id
      )

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
      {:ok, inv, stub, _handler} =
        test_invoice(
          store: store,
          required_confirmations: 3,
          payment_currency: :XMR,
          status: :open,
          manager: manager
        )

      InvoiceEvents.subscribe(inv)

      # First we see an unconfirmed tx

      txid =
        notify_tx(
          amount: inv.expected_payment.amount,
          height: 0,
          address: inv.address_id,
          store_id: store.id
        )

      assert_receive {{:invoice, :processing}, %{confirmations_due: 3}}

      # Then issue block and mark tx as included in the block

      MockRPCClient.expect(@client, "get_transfers", fn %{
                                                          account_index: 0,
                                                          subaddr_indices: _indices
                                                        } ->
        MoneroFixtures.get_transfers([
          %{txid: txid, address: inv.address_id, amount: inv.expected_payment.amount, height: 11}
        ])
      end)

      increase_block(height: 11)
      assert_receive {{:invoice, :processing}, %{confirmations_due: 2}}

      # Then more blocks

      increase_block(height: 12)
      assert_receive {{:invoice, :processing}, %{confirmations_due: 1}}

      increase_block(height: 13)
      HandlerSubscriberCollector.await_msg(stub, {:invoice, :paid})

      assert [
               {{:invoice, :finalized}, _},
               {{:invoice, :processing}, %{confirmations_due: 3}},
               {{:invoice, :processing}, %{confirmations_due: 2}},
               {{:invoice, :processing}, %{confirmations_due: 1}},
               {{:invoice, :paid}, _}
             ] = HandlerSubscriberCollector.received(stub)

      # MockRPCClient.verify!(@client)
    end

    test "multiple stores and wallets", %{store: store1, manager: manager} do
      store2 = create_store()
      _key2 = get_or_create_address_key(store2.id, @currency)

      {:ok, inv1, stub1, _handler} =
        test_invoice(
          store: store1,
          required_confirmations: 2,
          payment_currency: :XMR,
          status: :open,
          manager: manager,
          address: Enum.at(MoneroFixtures.addresses(), 0)
        )

      InvoiceEvents.subscribe(inv1)
      inv1_id = inv1.id

      wallet_init_messages()

      {:ok, inv2, stub2, _handler} =
        test_invoice(
          store: store2,
          required_confirmations: 2,
          payment_currency: :XMR,
          status: :open,
          manager: manager,
          address: Enum.at(MoneroFixtures.addresses(), 1)
        )

      InvoiceEvents.subscribe(inv2)
      inv2_id = inv2.id

      _txid1 =
        notify_tx(
          amount: inv1.expected_payment.amount,
          height: 10,
          address: inv1.address_id,
          store_id: store1.id
        )

      assert_receive {{:invoice, :processing}, %{id: ^inv1_id, confirmations_due: 1}}
      refute_receive {{:invoice, :processing}, %{id: ^inv2_id, confirmations_due: 1}}

      _txid2 =
        notify_tx(
          amount: inv2.expected_payment.amount,
          height: 10,
          address: inv2.address_id,
          store_id: store2.id
        )

      assert_receive {{:invoice, :processing}, %{id: ^inv2_id, confirmations_due: 1}}

      increase_block(height: 12)
      HandlerSubscriberCollector.await_msg(stub1, {:invoice, :paid})
      HandlerSubscriberCollector.await_msg(stub2, {:invoice, :paid})
    end
  end

  describe "unlock_times" do
    @tag init_backend: false
    test "reasonable_unlock_time?" do
      DataCase.setup_db(async: false)
      Blocks.new(:XMR, 100)

      valid_block_count = Settings.acceptable_unlock_time_blocks()

      assert Wallet.reasonable_unlock_time?(0)
      assert Wallet.reasonable_unlock_time?(100)

      assert Wallet.reasonable_unlock_time?(100 + valid_block_count)
      assert !Wallet.reasonable_unlock_time?(101 + valid_block_count)

      valid_minutes = Settings.acceptable_unlock_time_minutes()

      seconds_since_epoch =
        NaiveDateTime.utc_now()
        |> NaiveDateTime.truncate(:second)
        |> NaiveDateTime.diff(~N[1970-01-01 00:00:00])

      assert Wallet.reasonable_unlock_time?(500_000_000)
      assert Wallet.reasonable_unlock_time?(seconds_since_epoch)
      assert Wallet.reasonable_unlock_time?(seconds_since_epoch + valid_minutes * 60)
      assert !Wallet.reasonable_unlock_time?(seconds_since_epoch + valid_minutes * 60 + 1)
      assert !Wallet.reasonable_unlock_time?(999_999_999_999)
    end

    test "fail tx with unreasonable unlock time", %{store: store, manager: manager} do
      {:ok, inv, stub, _handler} =
        test_invoice(
          store: store,
          required_confirmations: 0,
          payment_currency: :XMR,
          double_spend_timeout: 1,
          status: :open,
          manager: manager
        )

      txid = TransactionFactory.unique_txid()

      MockRPCClient.expect(@client, "get_transfer_by_txid", fn %{txid: ^txid, account_index: 0} ->
        MoneroFixtures.get_transfer_by_txid(
          txid: txid,
          address: inv.address_id,
          height: 0,
          amount: inv.expected_payment.amount,
          unlock_time: 999_999_999_999
        )
      end)

      send(ExtNotificationHandler, {:notify, ["monero:tx-notify", txid, store.id], 0})

      HandlerSubscriberCollector.await_msg(stub, {:invoice, :uncollectible})
    end
  end

  describe "recovery" do
    @tag restart: :transient, block_hash: "block-hash"
    test "recheck 0-conf when starting", %{manager: manager, store: store} do
      {:ok, inv, stub, _handler} =
        test_invoice(
          store: store,
          required_confirmations: 0,
          payment_currency: :XMR,
          double_spend_timeout: 50,
          status: :open,
          manager: manager
        )

      BackendManager.stop_backend(manager, :XMR)

      assert_receive {{:backend, :status}, %{status: {:stopped, _}}}

      assert [
               {{:invoice, :finalized}, _}
             ] = HandlerSubscriberCollector.received(stub)

      txid = TransactionFactory.unique_txid()

      node_init_messages(block_hash: "block-hash")

      wallet_init_messages(
        txs: [
          %{amount: inv.expected_payment.amount, height: 0, txid: txid, address: inv.address_id}
        ]
      )

      MockRPCClient.expect(@client, "get_transfers", fn %{
                                                          account_index: 0,
                                                          subaddr_indices: [1]
                                                        } ->
        MoneroFixtures.get_transfers([
          %{
            txid: txid,
            address: inv.address_id,
            amount: inv.expected_payment.amount,
            height: 0
          }
        ])
      end)

      BackendManager.restart_backend(manager, :XMR)

      HandlerSubscriberCollector.await_msg(stub, {:invoice, :paid})

      assert [
               {{:invoice, :finalized}, _},
               {{:invoice, :processing}, _},
               {{:invoice, :paid}, _}
             ] = HandlerSubscriberCollector.received(stub)
    end

    @tag restart: :transient
    test "initialized require confs when down", %{manager: manager, store: store} do
      {:ok, inv, stub, _handler} =
        test_invoice(
          store: store,
          required_confirmations: 3,
          payment_currency: :XMR,
          status: :open,
          manager: manager
        )

      InvoiceEvents.subscribe(inv)

      BackendManager.stop_backend(manager, :XMR)

      assert_receive {{:backend, :status}, %{status: {:stopped, _}}}

      assert [
               {{:invoice, :finalized}, _}
             ] = HandlerSubscriberCollector.received(stub)

      txid = TransactionFactory.unique_txid()

      node_init_messages(height: 12)

      wallet_init_messages(
        txs: [
          %{amount: inv.expected_payment.amount, height: 11, txid: txid, address: inv.address_id}
        ]
      )

      MockRPCClient.expect(@client, "get_transfers", fn _ ->
        MoneroFixtures.get_transfers()
      end)

      BackendManager.restart_backend(manager, :XMR)

      # Must wait until the backend is ready and has subscribed to block-notify
      # before we send the bLock
      assert eventually(fn -> BackendManager.is_ready(:XMR) end)
      assert_receive {{:invoice, :processing}, %{confirmations_due: 1}}

      increase_block(height: 13)

      HandlerSubscriberCollector.await_msg(stub, {:invoice, :paid})

      assert [
               {{:invoice, :finalized}, _},
               {{:invoice, :processing}, _},
               {{:invoice, :paid}, _}
             ] = HandlerSubscriberCollector.received(stub)
    end

    @tag restart: :transient
    test "paid while down", %{manager: manager, store: store} do
      {:ok, inv, stub, _handler} =
        test_invoice(
          store: store,
          required_confirmations: 3,
          payment_currency: :XMR,
          status: :open,
          manager: manager
        )

      InvoiceEvents.subscribe(inv)

      BackendManager.stop_backend(manager, :XMR)

      assert_receive {{:backend, :status}, %{status: {:stopped, _}}}

      assert [
               {{:invoice, :finalized}, _}
             ] = HandlerSubscriberCollector.received(stub)

      txid = TransactionFactory.unique_txid()

      node_init_messages(height: 13)

      wallet_init_messages(
        txs: [
          %{
            amount: inv.expected_payment.amount,
            height: 11,
            txid: txid,
            address: inv.address_id
          }
        ]
      )

      MockRPCClient.expect(@client, "get_transfers", fn _ ->
        MoneroFixtures.get_transfers()
      end)

      BackendManager.restart_backend(manager, :XMR)

      assert eventually(fn -> BackendManager.is_ready(:XMR) end)

      HandlerSubscriberCollector.await_msg(stub, {:invoice, :paid})
    end
  end

  describe "reorg" do
    test "reorg above tx", %{manager: manager, store: store} do
      {:ok, inv, stub, _handler} =
        test_invoice(
          store: store,
          required_confirmations: 4,
          payment_currency: :XMR,
          status: :open,
          manager: manager
        )

      txid =
        notify_tx(
          height: 10,
          amount: inv.expected_payment.amount,
          address: inv.address_id,
          store_id: store.id
        )

      HandlerSubscriberCollector.await_msg(stub, {:invoice, :processing})

      increase_block(height: 11)
      HandlerSubscriberCollector.await_msg(stub, {:invoice, :processing})

      increase_block(height: 12)
      HandlerSubscriberCollector.await_msg(stub, {:invoice, :processing})

      # Reorg both blocks above the tx with a longer chain

      MockRPCClient.expect(@client, "get_transfers", fn %{
                                                          account_index: 0,
                                                          subaddr_indices: _indices
                                                        } ->
        MoneroFixtures.get_transfers([
          %{txid: txid, address: inv.address_id, amount: inv.expected_payment.amount, height: 10}
        ])
      end)

      send(
        ExtNotificationHandler,
        {:notify, ["monero:reorg-notify", 13, 10], 0}
      )

      HandlerSubscriberCollector.await_msg(stub, {:invoice, :paid})

      assert [
               {{:invoice, :finalized}, _},
               {{:invoice, :processing}, %{confirmations_due: 3}},
               {{:invoice, :processing}, %{confirmations_due: 2}},
               {{:invoice, :processing}, %{confirmations_due: 1}},
               {{:invoice, :paid}, _}
             ] = HandlerSubscriberCollector.received(stub)
    end

    test "reorg that reverses pending tx", %{manager: manager, store: store} do
      {:ok, inv, stub, _handler} =
        test_invoice(
          store: store,
          required_confirmations: 4,
          payment_currency: :XMR,
          status: :open,
          manager: manager
        )

      InvoiceEvents.subscribe(inv)

      increase_block(height: 11)

      txid =
        notify_tx(
          height: 11,
          amount: inv.expected_payment.amount,
          address: inv.address_id,
          store_id: store.id
        )

      assert_receive {{:invoice, :processing}, %{confirmations_due: 3}}

      # Reorg tx and make it unconfirmed

      MockRPCClient.expect(@client, "get_transfers", fn %{
                                                          account_index: 0,
                                                          subaddr_indices: _indices
                                                        } ->
        MoneroFixtures.get_transfers([
          %{txid: txid, address: inv.address_id, amount: inv.expected_payment.amount, height: 0}
        ])
      end)

      send(
        ExtNotificationHandler,
        {:notify, ["monero:reorg-notify", 13, 10], 0}
      )

      assert_receive {{:invoice, :processing}, %{confirmations_due: 4}}

      HandlerSubscriberCollector.await_msg(stub, {:invoice, :processing})

      increase_block(
        height: 14,
        txs: [
          %{amount: inv.expected_payment.amount, height: 14, txid: txid, address: inv.address_id}
        ]
      )

      assert_receive {{:invoice, :processing}, %{confirmations_due: 3}}

      increase_block(height: 15)
      assert_receive {{:invoice, :processing}, %{confirmations_due: 2}}

      increase_block(height: 16)
      assert_receive {{:invoice, :processing}, %{confirmations_due: 1}}

      increase_block(height: 17)
      HandlerSubscriberCollector.await_msg(stub, {:invoice, :paid})
    end
  end
end
