defmodule BitPal.Backend.MoneroTest do
  use ExUnit.Case, async: false
  use BitPal.CaseHelpers
  import Mox
  alias BitPal.Backend.Monero
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

    MockRPCClient.stub(@client, "store", fn _ ->
      {:ok, %{}}
    end)

    if Map.get(tags, :init_backend, true) do
      if Map.get(tags, :init_messages, true) do
        init_messages(tags)
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

  defp init_messages(opts \\ []) do
    height = opts[:height] || 10
    block_hash = opts[:block_hash] || CurrencyFactory.unique_block_id()

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
      MoneroFixtures.get_info(height: height, hash: block_hash)
    end)

    MockRPCClient.expect(@client, "get_transfers", fn _ ->
      MoneroFixtures.get_transfers(opts[:txs] || [])
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

    assert eventually(fn -> {:ok, _} = BackendManager.fetch_backend(res.manager, :XMR) end)

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

    MockRPCClient.expect(@client, "get_transfer_by_txid", fn %{txid: ^txid, account_index: 0} ->
      MoneroFixtures.get_transfer_by_txid(opts)
    end)

    send(ExtNotificationHandler, {:notify, ["monero:tx-notify", txid], 0})

    txid
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
        address: inv.address_id
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
        address: inv.address_id
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

      notify_tx(height: 10, amount: inv.expected_payment.amount, address: inv.address_id)

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

      # First we see an unconfirmed tx

      txid = notify_tx(amount: inv.expected_payment.amount, height: 0, address: inv.address_id)

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

      # Then more blocks

      increase_block(height: 12)
      increase_block(height: 13)

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

  describe "unlock_times" do
    @tag init_backend: false
    test "reasonable_unlock_time?" do
      DataCase.setup_db(async: false)
      Blocks.new(:XMR, 100)

      valid_block_count = Settings.acceptable_unlock_time_blocks()

      assert Monero.reasonable_unlock_time?(0)
      assert Monero.reasonable_unlock_time?(100)

      assert Monero.reasonable_unlock_time?(100 + valid_block_count)
      assert !Monero.reasonable_unlock_time?(101 + valid_block_count)

      valid_minutes = Settings.acceptable_unlock_time_minutes()

      seconds_since_epoch =
        NaiveDateTime.utc_now()
        |> NaiveDateTime.truncate(:second)
        |> NaiveDateTime.diff(~N[1970-01-01 00:00:00])

      assert Monero.reasonable_unlock_time?(500_000_000)
      assert Monero.reasonable_unlock_time?(seconds_since_epoch)
      assert Monero.reasonable_unlock_time?(seconds_since_epoch + valid_minutes * 60)
      assert !Monero.reasonable_unlock_time?(seconds_since_epoch + valid_minutes * 60 + 1)
      assert !Monero.reasonable_unlock_time?(999_999_999_999)
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

      send(ExtNotificationHandler, {:notify, ["monero:tx-notify", txid], 0})

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

      init_messages(
        txs: [
          %{amount: inv.expected_payment.amount, height: 0, txid: txid, address: inv.address_id}
        ],
        block_hash: "block-hash"
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

      BackendManager.stop_backend(manager, :XMR)

      assert_receive {{:backend, :status}, %{status: {:stopped, _}}}

      assert [
               {{:invoice, :finalized}, _}
             ] = HandlerSubscriberCollector.received(stub)

      txid = TransactionFactory.unique_txid()

      init_messages(
        txs: [
          %{amount: inv.expected_payment.amount, height: 11, txid: txid, address: inv.address_id}
        ],
        height: 12
      )

      BackendManager.restart_backend(manager, :XMR)

      # Must wait until the backend is ready and has subscribed to block-notify
      # before we send the bLock
      assert eventually(fn -> BackendManager.is_ready(:XMR) end)

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

      BackendManager.stop_backend(manager, :XMR)

      assert_receive {{:backend, :status}, %{status: {:stopped, _}}}

      assert [
               {{:invoice, :finalized}, _}
             ] = HandlerSubscriberCollector.received(stub)

      txid = TransactionFactory.unique_txid()

      init_messages(
        txs: [
          %{
            amount: inv.expected_payment.amount,
            height: 11,
            txid: txid,
            address: inv.address_id
          }
        ],
        height: 13
      )

      BackendManager.restart_backend(manager, :XMR)

      # Must wait until the backend is ready and has subscribed to block-notify
      # before we send the bLock
      assert eventually(fn -> BackendManager.is_ready(:XMR) end)

      HandlerSubscriberCollector.await_msg(stub, {:invoice, :paid})

      assert [
               {{:invoice, :finalized}, _},
               {{:invoice, :processing}, _},
               {{:invoice, :paid}, _}
             ] = HandlerSubscriberCollector.received(stub)
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

      txid = notify_tx(height: 10, amount: inv.expected_payment.amount, address: inv.address_id)
      increase_block(height: 11)
      increase_block(height: 12)

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

      increase_block(height: 11)
      txid = notify_tx(height: 11, amount: inv.expected_payment.amount, address: inv.address_id)

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

      increase_block(
        height: 14,
        txs: [
          %{amount: inv.expected_payment.amount, height: 14, txid: txid, address: inv.address_id}
        ]
      )

      increase_block(height: 15)
      increase_block(height: 16)
      increase_block(height: 17)

      HandlerSubscriberCollector.await_msg(stub, {:invoice, :paid})

      assert [
               {{:invoice, :finalized}, _},
               {{:invoice, :processing}, %{confirmations_due: 3}},
               {{:invoice, :processing}, %{confirmations_due: 4}},
               {{:invoice, :processing}, %{confirmations_due: 3}},
               {{:invoice, :processing}, %{confirmations_due: 2}},
               {{:invoice, :processing}, %{confirmations_due: 1}},
               {{:invoice, :paid}, _}
             ] = HandlerSubscriberCollector.received(stub)
    end
  end
end
