defmodule BitPal.Backend.BCHNTest do
  use ExUnit.Case, async: false
  use BitPal.CaseHelpers
  import Mox
  alias BitPal.InvoiceEvents
  alias BitPal.Backend.BCHNFixtures
  alias BitPal.Backend.BCHN
  alias BitPal.BackendManager
  alias BitPal.BackendStatusSupervisor
  alias BitPal.BackendEvents
  alias BitPal.Blocks
  alias BitPal.ExtNotificationHandler
  alias BitPal.HandlerSubscriberCollector
  alias BitPal.IntegrationCase
  alias BitPal.MockRPCClient
  alias BitPalFactory.CurrencyFactory
  alias BitPalFactory.TransactionFactory

  @currency :BCH
  @client BitPal.BCHNMock

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup tags do
    # So... For some reason on_exit is delayed, which messes up the next tests
    # as there's some handler that hasn't stopped...
    IntegrationCase.remove_invoice_handlers([:BCH])

    BackendEvents.subscribe(@currency)

    MockRPCClient.init_mock(@client, missing_call_reply: tags[:missing_call_reply])

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

    MockRPCClient.expect(@client, "getnetworkinfo", fn _ ->
      BCHNFixtures.getnetworkinfo()
    end)

    MockRPCClient.expect(@client, "createwallet", fn _ ->
      BCHNFixtures.createwallet()
    end)

    MockRPCClient.stub(@client, "listsinceblock", fn _ ->
      BCHNFixtures.listsinceblock()
    end)

    MockRPCClient.expect(@client, "getblockchaininfo", fn _ ->
      BCHNFixtures.getblockchaininfo(height: height, hash: block_hash)
    end)

    MockRPCClient.stub(@client, "importaddress", fn _ ->
      {:ok, %{}}
    end)
  end

  defp init_backend(tags) do
    backends = [
      {BitPal.Backend.BCHN,
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
      assert eventually(fn -> {:ok, _} = BackendManager.fetch_backend(res.manager, @currency) end)
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

    if params.status == :draft do
      create_invoice(params)
    else
      HandlerSubscriberCollector.create_invoice(params)
    end
  end

  defp increase_block(opts) do
    height = Keyword.fetch!(opts, :height)

    MockRPCClient.expect(@client, "getblockchaininfo", fn _ ->
      BCHNFixtures.getblockchaininfo(height: height)
    end)

    send(
      ExtNotificationHandler,
      {:notify, ["bch:block-notify", CurrencyFactory.unique_block_id()], 0}
    )
  end

  defp notify_tx(opts) do
    opts = Keyword.put_new_lazy(opts, :txid, &TransactionFactory.unique_txid/0)
    txid = Keyword.fetch!(opts, :txid)

    MockRPCClient.expect(@client, "gettransaction", fn %{txid: ^txid} ->
      BCHNFixtures.gettransaction(opts)
    end)

    send(ExtNotificationHandler, {:notify, ["bch:wallet-notify", "test-wallet", txid], 0})

    txid
  end

  describe "setup and sync" do
    @tag init_wallet_messages: false
    @tag missing_call_reply: {:error, :connerror}, init_backend: false
    test "successful setup with sync reporting" do
      BackendStatusSupervisor.configure_status_handler(@currency, %{rate_limit: 1})

      MockRPCClient.expect(@client, "getnetworkinfo", fn _ ->
        BCHNFixtures.getnetworkinfo()
      end)

      MockRPCClient.expect(@client, "createwallet", fn _ ->
        BCHNFixtures.createwallet()
      end)

      MockRPCClient.stub(@client, "listsinceblock", fn _ ->
        BCHNFixtures.listsinceblock()
      end)

      MockRPCClient.expect(@client, "getblockchaininfo", fn _ ->
        BCHNFixtures.getblockchaininfo(progress: 0.2)
      end)

      MockRPCClient.expect(@client, "getblockchaininfo", fn _ ->
        BCHNFixtures.getblockchaininfo(progress: 0.8)
      end)

      MockRPCClient.expect(@client, "getblockchaininfo", fn _ ->
        BCHNFixtures.getblockchaininfo(progress: 0.99999999, height: 21)
      end)

      init_backend(%{await_ready: false})

      assert_receive {{:backend, :status}, %{status: :starting}}
      assert_receive {{:backend, :status}, %{status: {:syncing, 0.2}}}
      assert_receive {{:backend, :status}, %{status: {:syncing, 0.8}}}
      assert_receive {{:backend, :status}, %{status: :ready}}

      # Sets block height from info
      eventually(fn ->
        Blocks.fetch_height(@currency) == {:ok, 21}
      end)

      MockRPCClient.verify!(@client)
    end

    @tag await_ready: false
    @tag missing_call_reply: {:error, :connerror}, init_messages: false
    test "stops after init if we can't connect" do
      assert eventually(fn ->
               BackendManager.status(@currency) == {:stopped, {:shutdown, :connerror}}
             end)

      MockRPCClient.verify!(@client)
    end

    @tag await_ready: false
    @tag restart: :transient, log_level: :critical
    test "restart after closed connection" do
      assert eventually(fn ->
               BackendManager.status(@currency) == :ready
             end)

      MockRPCClient.expect(@client, "getblockchaininfo", fn _ ->
        {:error, :econnerror}
      end)

      init_messages()

      send(ExtNotificationHandler, {:notify, ["bch:block-notify", "block-id"], 0})

      assert_receive {{:backend, :status},
                      %{
                        status: {:stopped, {:error, :unknown}}
                      }}

      assert_receive {{:backend, :status}, %{status: :starting}}
      assert_receive {{:backend, :status}, %{status: :ready}}
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

      assert invoice.address_id == nil
      {:ok, invoice} = BCHN.assign_address(BCHN, invoice)
      assert invoice.address_id != nil
    end

    test "assign increases xpub index", %{store: store} do
      for i <- 1..4 do
        invoice = test_invoice(store: store)
        {:ok, invoice} = BCHN.assign_address(BCHN, invoice)
        assert invoice.address_id != nil
        assert invoice.address.address_index == i - 1
      end
    end
  end

  describe "transaction acceptance" do
    test "0-conf acceptance", %{store: store, manager: manager} do
      {:ok, inv, stub, _handler} =
        test_invoice(
          store: store,
          required_confirmations: 0,
          double_spend_timeout: 1,
          status: :open,
          manager: manager
        )

      txid = TransactionFactory.unique_txid()

      # For checking before accepting 0-conf
      MockRPCClient.expect(@client, "listreceivedbyaddress", fn _ ->
        BCHNFixtures.listreceivedbyaddress([
          %{
            txid: txid,
            address: inv.address_id,
            amount: inv.expected_payment,
            confirmations: 0
          }
        ])
      end)

      notify_tx(
        txid: txid,
        confirmations: 0,
        amount: inv.expected_payment,
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
          double_spend_timeout: 1,
          status: :open,
          manager: manager
        )

      txid = TransactionFactory.unique_txid()

      # For checking before accepting 0-conf
      MockRPCClient.expect(@client, "listreceivedbyaddress", fn _ ->
        BCHNFixtures.listreceivedbyaddress([
          %{
            txid: txid,
            address: inv.address_id,
            amount: inv.expected_payment,
            confirmations: -1
          }
        ])
      end)

      notify_tx(
        txid: txid,
        confirmations: 0,
        amount: inv.expected_payment,
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
          status: :open,
          manager: manager
        )

      notify_tx(
        confirmations: 1,
        amount: inv.expected_payment,
        address: inv.address_id
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
          status: :open,
          manager: manager
        )

      InvoiceEvents.subscribe(inv)

      # First we see an unconfirmed tx

      txid =
        notify_tx(
          amount: inv.expected_payment,
          confirmations: 0,
          address: inv.address_id
        )

      assert_receive {{:invoice, :processing}, %{confirmations_due: 3}}

      # Then issue block and mark tx as included in the block

      MockRPCClient.expect(@client, "listsinceblock", fn _ ->
        BCHNFixtures.listsinceblock(
          txs: [
            %{
              txid: txid,
              address: inv.address_id,
              amount: inv.expected_payment,
              confirmations: 1
            }
          ]
        )
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

      MockRPCClient.verify!(@client)
    end
  end

  describe "recovery" do
    @tag restart: :transient, block_hash: "block-hash"
    test "recheck 0-conf when starting", %{manager: manager, store: store} do
      {:ok, inv, stub, _handler} =
        test_invoice(
          store: store,
          required_confirmations: 0,
          double_spend_timeout: 50,
          status: :open,
          manager: manager
        )

      BackendManager.stop_backend(manager, @currency)

      assert_receive {{:backend, :status}, %{status: {:stopped, _}}}

      assert [
               {{:invoice, :finalized}, _}
             ] = HandlerSubscriberCollector.received(stub)

      txid = TransactionFactory.unique_txid()

      init_messages(block_hash: "block-hash")

      txs = [
        %{txid: txid, address: inv.address_id, amount: inv.expected_payment, confirmations: 0}
      ]

      MockRPCClient.expect(@client, "listsinceblock", fn _ ->
        BCHNFixtures.listsinceblock(txs: txs)
      end)

      MockRPCClient.expect(@client, "listreceivedbyaddress", 2, fn _ ->
        BCHNFixtures.listreceivedbyaddress(txs)
      end)

      BackendManager.restart_backend(manager, @currency)

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
          status: :open,
          manager: manager
        )

      InvoiceEvents.subscribe(inv)

      BackendManager.stop_backend(manager, @currency)

      assert_receive {{:backend, :status}, %{status: {:stopped, _}}}

      assert [
               {{:invoice, :finalized}, _}
             ] = HandlerSubscriberCollector.received(stub)

      txid = TransactionFactory.unique_txid()

      init_messages(height: 12)

      txs = [
        %{txid: txid, address: inv.address_id, amount: inv.expected_payment, confirmations: 2}
      ]

      MockRPCClient.expect(@client, "listsinceblock", fn _ ->
        BCHNFixtures.listsinceblock(txs: txs)
      end)

      MockRPCClient.expect(@client, "listreceivedbyaddress", 2, fn _ ->
        BCHNFixtures.listreceivedbyaddress(txs)
      end)

      BackendManager.restart_backend(manager, @currency)

      # Must wait until the backend is ready and has subscribed to block-notify
      # before we send the bLock
      assert eventually(fn -> BackendManager.is_ready(@currency) end)
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
          status: :open,
          manager: manager
        )

      InvoiceEvents.subscribe(inv)

      BackendManager.stop_backend(manager, @currency)

      assert_receive {{:backend, :status}, %{status: {:stopped, _}}}

      assert [
               {{:invoice, :finalized}, _}
             ] = HandlerSubscriberCollector.received(stub)

      txid = TransactionFactory.unique_txid()

      init_messages(height: 13)

      txs = [
        %{txid: txid, address: inv.address_id, amount: inv.expected_payment, confirmations: 3}
      ]

      MockRPCClient.expect(@client, "listsinceblock", fn _ ->
        BCHNFixtures.listsinceblock(txs: txs)
      end)

      MockRPCClient.expect(@client, "listreceivedbyaddress", 2, fn _ ->
        BCHNFixtures.listreceivedbyaddress(txs)
      end)

      BackendManager.restart_backend(manager, @currency)

      assert eventually(fn -> BackendManager.is_ready(@currency) end)

      HandlerSubscriberCollector.await_msg(stub, {:invoice, :paid})
    end
  end

  #
  # describe "reorg" do
  #   test "reorg above tx", %{manager: manager, store: store} do
  #     {:ok, inv, stub, _handler} =
  #       test_invoice(
  #         store: store,
  #         required_confirmations: 4,
  #         payment_currency: :XMR,
  #         status: :open,
  #         manager: manager
  #       )
  #
  #     txid =
  #       notify_tx(
  #         height: 10,
  #         amount: inv.expected_payment.amount,
  #         address: inv.address_id,
  #         store_id: store.id
  #       )
  #
  #     HandlerSubscriberCollector.await_msg(stub, {:invoice, :processing})
  #
  #     increase_block(height: 11)
  #     HandlerSubscriberCollector.await_msg(stub, {:invoice, :processing})
  #
  #     increase_block(height: 12)
  #     HandlerSubscriberCollector.await_msg(stub, {:invoice, :processing})
  #
  #     # Reorg both blocks above the tx with a longer chain
  #
  #     MockRPCClient.expect(@client, "get_transfers", fn %{
  #                                                         account_index: 0,
  #                                                         subaddr_indices: _indices
  #                                                       } ->
  #       MoneroFixtures.get_transfers([
  #         %{txid: txid, address: inv.address_id, amount: inv.expected_payment.amount, height: 10}
  #       ])
  #     end)
  #
  #     send(
  #       ExtNotificationHandler,
  #       {:notify, ["monero:reorg-notify", 13, 10], 0}
  #     )
  #
  #     HandlerSubscriberCollector.await_msg(stub, {:invoice, :paid})
  #
  #     assert [
  #              {{:invoice, :finalized}, _},
  #              {{:invoice, :processing}, %{confirmations_due: 3}},
  #              {{:invoice, :processing}, %{confirmations_due: 2}},
  #              {{:invoice, :processing}, %{confirmations_due: 1}},
  #              {{:invoice, :paid}, _}
  #            ] = HandlerSubscriberCollector.received(stub)
  #   end
  #
  #   test "reorg that reverses pending tx", %{manager: manager, store: store} do
  #     {:ok, inv, stub, _handler} =
  #       test_invoice(
  #         store: store,
  #         required_confirmations: 4,
  #         payment_currency: :XMR,
  #         status: :open,
  #         manager: manager
  #       )
  #
  #     InvoiceEvents.subscribe(inv)
  #
  #     increase_block(height: 11)
  #
  #     txid =
  #       notify_tx(
  #         height: 11,
  #         amount: inv.expected_payment.amount,
  #         address: inv.address_id,
  #         store_id: store.id
  #       )
  #
  #     assert_receive {{:invoice, :processing}, %{confirmations_due: 3}}
  #
  #     # Reorg tx and make it unconfirmed
  #
  #     MockRPCClient.expect(@client, "get_transfers", fn %{
  #                                                         account_index: 0,
  #                                                         subaddr_indices: _indices
  #                                                       } ->
  #       MoneroFixtures.get_transfers([
  #         %{txid: txid, address: inv.address_id, amount: inv.expected_payment.amount, height: 0}
  #       ])
  #     end)
  #
  #     send(
  #       ExtNotificationHandler,
  #       {:notify, ["monero:reorg-notify", 13, 10], 0}
  #     )
  #
  #     assert_receive {{:invoice, :processing}, %{confirmations_due: 4}}
  #
  #     HandlerSubscriberCollector.await_msg(stub, {:invoice, :processing})
  #
  #     increase_block(
  #       height: 14,
  #       txs: [
  #         %{amount: inv.expected_payment.amount, height: 14, txid: txid, address: inv.address_id}
  #       ]
  #     )
  #
  #     assert_receive {{:invoice, :processing}, %{confirmations_due: 3}}
  #
  #     increase_block(height: 15)
  #     assert_receive {{:invoice, :processing}, %{confirmations_due: 2}}
  #
  #     increase_block(height: 16)
  #     assert_receive {{:invoice, :processing}, %{confirmations_due: 1}}
  #
  #     increase_block(height: 17)
  #     HandlerSubscriberCollector.await_msg(stub, {:invoice, :paid})
  #   end
  # end
end
