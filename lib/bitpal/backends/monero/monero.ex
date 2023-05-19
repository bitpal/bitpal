defmodule BitPal.Backend.Monero do
  use BitPal.Backend, currency_id: :XMR
  alias BitPal.Blocks
  alias BitPal.ExtNotificationHandler
  alias BitPal.Backend.Monero.DaemonRPC
  alias BitPal.Backend.Monero.Wallet
  alias BitPal.Backend.Monero.WalletRPC
  alias BitPal.Addresses
  alias BitPal.Transactions
  alias BitPal.Invoices
  require Logger

  @supervisor MoneroSupervisor
  # FIXME configurable what account we should pass our payments to
  @account 0
  @start_wallet Application.compile_env(:bitpal, [BitPal.Backend.Monero, :init_wallet], true)

  # Client API

  @impl Backend
  def assign_address(backend, invoice) do
    GenServer.call(backend, {:assign_address, invoice})
  end

  @impl Backend
  def watch_invoice(_backend, _invoice) do
    # No need to manually watch addresses as the wallet will do this for us.
    :ok
  end

  @impl Backend
  def info(backend), do: GenServer.call(backend, :get_info)

  @impl Backend
  def refresh_info(_backend), do: :ok

  # Server API

  @impl true
  def handle_continue(:init, opts) do
    Logger.notice("Starting Monero backend")
    Process.flag(:trap_exit, true)

    state =
      Enum.into(opts, %{
        rpc_client: BitPal.RPCClient,
        reconnect_timeout: 1_000,
        sync_check_interval: 1_000,
        daemon_check_interval: 30_000
      })

    {:noreply, state, {:continue, :connect_daemon}}
  end

  @impl true
  def handle_continue(:connect_daemon, state) do
    case DaemonRPC.get_version(state.rpc_client) do
      {:ok, %{"version" => version}} ->
        state =
          state
          |> Map.put(:daemon_version, version)
          |> Map.delete(:connect_attempt)

        {:noreply, state, {:continue, :start_wallet}}

      {:error, error} ->
        attempt = state[:connect_attempt] || 0

        if attempt > 10 do
          {:stop, {:shutdown, error}, state}
        else
          Process.sleep(state.reconnect_timeout)
          {:noreply, Map.put(state, :connect_attempt, attempt + 1), {:continue, :connect_daemon}}
        end
    end
  end

  @impl true
  def handle_continue(:start_wallet, state) do
    if @start_wallet do
      # During testing we don't want to launch an external command.
      # Could mock this I guess, but this is the single place it's needed so this was easier.
      Supervisor.start_link(
        [
          Wallet.executable_child_spec()
        ],
        strategy: :one_for_one,
        name: @supervisor
      )
    end

    {:noreply, state, {:continue, :connect_wallet}}
  end

  @impl true
  def handle_continue(:connect_wallet, state) do
    case WalletRPC.get_version(state.rpc_client) do
      {:ok, %{"version" => version}} ->
        state =
          state
          |> Map.put(:wallet_version, version)
          |> Map.delete(:connect_attempt)

        {:noreply, state, {:continue, :finalize_setup}}

      {:error, error} ->
        attempt = state[:connect_attempt] || 0

        if attempt > 10 do
          {:stop, {:shutdown, error}, state}
        else
          Process.sleep(state.reconnect_timeout)
          {:noreply, Map.put(state, :connect_attempt, attempt + 1), {:continue, :connect_wallet}}
        end
    end
  end

  @impl true
  def handle_continue(:finalize_setup, state) do
    {:noreply, update_sync(state)}
  end

  @impl true
  def handle_call({:assign_address, invoice}, _from, state) do
    res =
      Invoices.ensure_address(invoice, fn _key ->
        {:ok, %{"address" => address, "address_index" => index}} =
          WalletRPC.create_address(state.rpc_client, @account)

        {:ok, %{address_id: address, address_index: index}}
      end)

    {:reply, res, state}
  end

  @impl true
  def handle_call(:get_info, _from, state) do
    {:reply, create_info(state), state}
  end

  @impl true
  def handle_info(:update_info, state) do
    {:ok, state} = get_info(state)
    Process.send_after(self(), :update_info, state.daemon_check_interval)
    {:noreply, state}
  end

  @impl true
  def handle_info({:notify, "monero:tx-notify", [txid]}, state) do
    Logger.info("tx notify: #{txid}")
    update_tx(txid, state)
    {:noreply, state}
  end

  @impl true
  def handle_info({:notify, "monero:block-notify", msg}, state) do
    Logger.info("block notify: #{inspect(msg)}")
    {:ok, state} = get_info(state)
    {:noreply, state}
  end

  @impl true
  def handle_info({:notify, "monero:reorg-notify", [new_height, split_height]}, state) do
    Logger.warn("reorg detected!: new_height: #{new_height} split_height: #{split_height}")

    # Recheck all transactions that may be affected by the reorg.
    # Maybe this should be refactored out from backends?
    unless Blocks.reorg(:XMR, new_height, split_height) == :no_reorg do
      # NOTE It's possible that we'll miss already paid transactions if we only check active addresses.
      update_active_addresses(state)
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:update_tx, txid}, state) do
    update_tx(txid, state)
    {:noreply, state}
  end

  @impl true
  def handle_info(:update_sync, state) do
    {:noreply, update_sync(state)}
  end

  @impl true
  def terminate(reason, state) do
    # Try to save our progress when process aborts for some reason.
    WalletRPC.store(state.rpc_client)
    reason
  rescue
    _ ->
      reason
  end

  # Internal impl

  defp update_tx(txid, state) do
    case WalletRPC.get_transfer_by_txid(state.rpc_client, txid, @account) do
      {:ok, %{"transfer" => txinfo}} ->
        update_tx_info(txinfo)

      error ->
        Logger.error("Failed to get tx: `#{txid}`: #{inspect(error)}")
    end
  end

  defp update_tx_info(%{
         "address" => address,
         "amount" => amount,
         "double_spend_seen" => double_spend_seen,
         "height" => height,
         "txid" => txid,
         "type" => type
       }) do
    outputs = [{address, Money.new(amount, :XMR)}]

    Transactions.update(txid,
      outputs: outputs,
      height: height,
      double_spent: double_spend_seen,
      failed: type == "failed"
    )

    :ok
  end

  @spec get_info(map) :: {:ok, map} | {:error, term}
  defp get_info(state) do
    case DaemonRPC.get_info(state.rpc_client) do
      {:ok, info} -> {:ok, update_daemon_info(info, state)}
      {:error, error} -> {:error, error}
    end
  end

  defp update_daemon_info(info, state) do
    state
    |> update_height(info)
    |> store_daemon_info(info)
  end

  defp update_height(state, %{"height" => height, "top_block_hash" => hash}) do
    unless Blocks.new(:XMR, height, hash) == :not_updated do
      update_active_addresses(state)

      # Not sure if this is overkill, but we should store wallet progress periodically to
      # not have to do a slow resync on restart.
      WalletRPC.store(state.rpc_client)
    end

    state
  end

  defp update_active_addresses(state) do
    address_indices =
      Enum.map(Addresses.all_active(:XMR), fn a ->
        a.address_index
      end)

    {:ok, res} = WalletRPC.get_transfers(state.rpc_client, @account, address_indices)
    update_txs(res["in"])
    update_txs(res["pending"])
    update_txs(res["failed"])
    update_txs(res["pool"])
  end

  defp update_txs(txs) when is_list(txs) do
    for tx <- txs do
      update_tx_info(tx)
    end
  end

  defp update_txs(_), do: nil

  defp store_daemon_info(state, info) do
    BackendEvents.broadcast({{:backend, :info}, %{info: info, currency_id: :XMR}})
    Map.put(state, :daemon_info, info)
  end

  defp update_sync(state) do
    {:ok, %{"height" => wallet_height}} = WalletRPC.get_height(state.rpc_client)

    {:ok, %{"height" => daemon_height, "target_height" => target_height}} =
      DaemonRPC.sync_info(state.rpc_client)

    cond do
      target_height == 0 && wallet_height == daemon_height ->
        # We're all synced up

        # Wait until wallet and daemon are connected before we accept notifies.
        # Protects against race conditions where we try to make RPC calls that will
        # fail because they aren't ready yet.
        # Since we do this in continue that won't happen anyway, but this way we ignore
        # notifies that we shouldn't act on anyway.
        ExtNotificationHandler.subscribe("monero:tx-notify")
        ExtNotificationHandler.subscribe("monero:block-notify")
        ExtNotificationHandler.subscribe("monero:reorg-notify")

        {:ok, state} = get_info(state)

        # We should poll regularly even though we also use notifications.
        Process.send_after(self(), :update_info, state.daemon_check_interval)

        sync_done()

        state

      target_height == 0 ->
        # Daemon is synced, but wallet is not
        set_syncing({wallet_height, daemon_height})

        Process.send_after(self(), :update_sync, state.sync_check_interval)

        state

      true ->
        # Daemon isn't synced
        set_syncing({min(wallet_height, daemon_height), target_height})

        Process.send_after(self(), :update_sync, state.sync_check_interval)

        state
    end
  end

  defp create_info(state) do
    Map.get(state, :daemon_info, %{})
  end
end
