defmodule BitPal.Backend.BCHN do
  use BitPal.Backend, currency_id: :BCH
  alias BitPal.Transactions
  alias BitPal.Addresses
  alias BitPal.Invoices
  alias BitPal.Blocks
  alias BitPal.ExtNotificationHandler
  alias BitPal.Backend.BCHN.DaemonRPC
  alias BitPal.Backend.BCHN.Settings
  alias BitPal.BCH.Cashaddress
  require Logger

  # Client API

  @impl Backend
  def assign_address(_backend, invoice) do
    Invoices.ensure_address(invoice, fn key ->
      index = Addresses.next_address_index(key)
      {:ok, %{address_id: Cashaddress.derive_address(key.data.xpub, index), address_index: index}}
    end)
  end

  @impl Backend
  def assign_payment_uri(_backend, invoice) do
    Invoices.assign_payment_uri(invoice, %{
      prefix: "bitcoincash",
      decimal_amount_key: "amount",
      description_key: "message",
      recipient_name_key: "label"
    })
  end

  @impl Backend
  def watch_invoice(backend, invoice) do
    GenServer.call(backend, {:watch_invoice, invoice})
  end

  @impl Backend
  def update_address(backend, invoice) do
    GenServer.call(backend, {:update_address, invoice})
  end

  @impl Backend
  def info(backend), do: GenServer.call(backend, :info)

  # TODO
  @impl Backend
  def refresh_info(_backend), do: :ok

  # Sever API

  @impl true
  def handle_continue(:init, opts) do
    Logger.notice("Starting BCHN backend")

    state =
      Enum.into(opts, %{
        rpc_client: BitPal.RPCClient,
        reconnect_timeout: 1_000,
        sync_check_interval: 1_000,
        # NOTE that if we increase the interval to 30s the RPC connection may
        # get a closed error. No idea why this happens, so let's just keep this
        # as it's working.
        daemon_check_interval: 20_000
      })

    {:noreply, state, {:continue, :connect}}
  end

  @impl true
  def handle_continue(:connect, state) do
    case DaemonRPC.getnetworkinfo(state.rpc_client) do
      {:ok, info} ->
        state =
          state
          |> set_networkinfo(info)
          |> Map.delete(:connect_attempt)

        {:noreply, state, {:continue, :init_wallet}}

      {:error, error} ->
        attempt = state[:connect_attempt] || 0

        if attempt > 10 do
          {:stop, {:shutdown, error}, state}
        else
          Process.sleep(state.reconnect_timeout)
          {:noreply, Map.put(state, :connect_attempt, attempt + 1), {:continue, :connect}}
        end
    end
  end

  @impl true
  def handle_continue(:init_wallet, state) do
    file = Settings.wallet_file()

    if File.exists?(file) do
      # Note that this call may return an error due to duplicate wallet loading, if this plugin is loaded
      # multiple times. This is fine.
      DaemonRPC.loadwallet(state.rpc_client, file)
    else
      {:ok, _} = DaemonRPC.createwallet(state.rpc_client, file)
    end

    {:noreply, state, {:continue, :watch_addresses}}
  end

  @impl true
  def handle_continue(:watch_addresses, state) do
    # Watch addresses before updating blockchain info, so listsinceblock respects them.
    active_addresses = Addresses.all_active_ids(:BCH)

    Enum.each(active_addresses, fn address ->
      watch_address(address, state)
    end)

    {:noreply, Map.put(state, :active_addresses, active_addresses), {:continue, :update_info}}
  end

  @impl true
  def handle_continue(:update_info, state) do
    {:noreply, update_blockchain_info(state), {:continue, :recover_state}}
  end

  @impl true
  def handle_continue(:recover_state, state) do
    height = Blocks.fetch_height!(:BCH)

    # listsincebLock should cover most, but if we crash after updating a block but before
    # updating txs there's a risk that we miss out. So double check all active addresses here.
    Enum.each(state.active_addresses, fn address ->
      update_address_txs(address, height, state)
    end)

    {:noreply, Map.delete(state, :active_addresses), {:continue, :finalize_setup}}
  end

  @impl true
  def handle_continue(:finalize_setup, state) do
    ExtNotificationHandler.subscribe("bch:alert-notify")
    ExtNotificationHandler.subscribe("bch:wallet-notify")
    ExtNotificationHandler.subscribe("bch:block-notify")
    {:noreply, state}
  end

  @impl true
  def handle_call(:info, _from, state) do
    {:reply, state.info, state}
  end

  @impl true
  def handle_call({:watch_invoice, invoice}, _from, state) do
    watch_address(invoice.address_id, state)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:update_address, invoice}, _from, state) do
    # FIXME
    # It's possible this can miss certain transactions!
    # For example, if we're waiting for a 0-conf but the service is shut down.
    # Then we'll update the block (but miss the tx) and now when we ask about
    # the state then we'll miss the last block! Ugh!
    update_address_txs(invoice.address_id, Blocks.fetch_height!(:BCH), state)
    {:reply, :ok, state}
  end

  @impl true
  def handle_info(:update_info, state) do
    {:noreply, update_blockchain_info(state)}
  end

  @impl true
  def handle_info({:notify, "bch:block-notify", msg}, state) do
    Logger.info("block notify: #{inspect(msg)}")
    {:noreply, update_blockchain_info(state)}
  end

  @impl true
  def handle_info({:notify, "bch:alert-notify", msg}, state) do
    Logger.warning("alert notify: #{inspect(msg)}")
    {:noreply, update_blockchain_info(state)}
  end

  @impl true
  def handle_info({:notify, "bch:wallet-notify", [wallet, txid]}, state) do
    Logger.info("wallet notify: wallet: #{wallet} txid: #{txid}")
    update_tx_info(state, txid)
    {:noreply, state}
  end

  defp watch_address(address, state) do
    {:ok, _} = DaemonRPC.importaddress(state.rpc_client, Settings.wallet_file(), address)
  end

  defp update_blockchain_info(state) do
    {:ok,
     info = %{
       "bestblockhash" => block_hash,
       "blocks" => block_height,
       "verificationprogress" => progress
     }} = DaemonRPC.getblockchaininfo(state.rpc_client)

    if progress < 0.9999 do
      set_syncing(progress)
      Process.send_after(self(), :update_info, state.sync_check_interval)
    else
      sync_done()
      Process.send_after(self(), :update_info, state.daemon_check_interval)
    end

    case Blocks.new(:BCH, block_height, block_hash) do
      {:updated, %{prev_hash: prev_hash}} ->
        {:ok, %{"removed" => removed, "transactions" => updated}} =
          DaemonRPC.listsinceblock(state.rpc_client, Settings.wallet_file(), prev_hash)

        update_txs(removed, block_height)
        update_txs(updated, block_height)

      _ ->
        nil
    end

    state
    |> set_blockchain_info(info)
  end

  defp update_tx_info(state, txid) do
    case DaemonRPC.gettransaction(state.rpc_client, Settings.wallet_file(), txid) do
      {:ok, txinfo} -> update_tx(txinfo)
      error -> Logger.warning("request failed: #{inspect(error)}")
    end
  end

  defp update_txs(txs, top_block_height) when is_list(txs) do
    for tx <- txs do
      update_tx(tx, top_block_height)
    end
  end

  defp update_tx(
         %{
           "txid" => txid,
           "address" => address,
           "amount" => amount,
           "confirmations" => confirmations
         },
         top_block_height
       ) do
    outputs = [{address, Money.parse!(amount, :BCH)}]
    update_tx(txid, confirmations, outputs, top_block_height)
  end

  defp update_tx(%{
         "txid" => txid,
         "confirmations" => confirmations,
         "details" => outputs
       }) do
    outputs =
      Enum.map(outputs, fn %{"address" => address, "amount" => amount} ->
        {address, Money.parse!(amount, :BCH)}
      end)

    top_block_height = Blocks.fetch_height!(:BCH)
    update_tx(txid, confirmations, outputs, top_block_height)
  end

  defp update_tx(txid, confirmations, outputs, top_block_height) do
    cond do
      # Can be negative! In that case it's been conflicted and reversed.
      confirmations < 0 ->
        Transactions.update(txid,
          outputs: outputs,
          height: 0,
          double_spent: true,
          failed: true,
          reorg: true
        )

      confirmations > 0 ->
        Transactions.update(txid,
          outputs: outputs,
          height: top_block_height - confirmations + 1
        )

      confirmations == 0 ->
        # TODO, if required_confirmations == 0 then check fees etc for 0-conf availablity
        Transactions.update(txid,
          outputs: outputs,
          height: 0
        )
    end

    :ok
  end

  defp update_address_txs(address, height, state) do
    case DaemonRPC.listreceivedbyaddress(state.rpc_client, Settings.wallet_file(), address) do
      {:ok, info} -> update_received_by_address(info, height, state)
      error -> Logger.warning("request failed: #{inspect(error)}")
    end
  end

  defp update_received_by_address(info, top_block_height, state) when is_list(info) do
    for x <- info do
      update_received_by_address(x, top_block_height, state)
    end
  end

  defp update_received_by_address(
         %{
           "address" => address,
           "amount" => amount,
           "confirmations" => confirmations,
           "txids" => [txid]
         },
         top_block_height,
         _state
       ) do
    update_tx(txid, confirmations, [{address, Money.parse!(amount, :BCH)}], top_block_height)
  end

  defp update_received_by_address(
         %{
           "txids" => txids
         },
         _top_block_height,
         state
       ) do
    for txid <- txids do
      update_tx_info(state, txid)
    end
  end

  defp set_networkinfo(state, info) do
    Map.put(
      state,
      :info,
      Map.take(info, [
        "protocolversion",
        "version",
        "subversion",
        "warnings",
        "verificationprogress"
      ])
    )
  end

  defp set_blockchain_info(state, blockchain_info) do
    Map.update!(state, :info, fn info ->
      Map.merge(info, blockchain_info)
    end)
  end
end
