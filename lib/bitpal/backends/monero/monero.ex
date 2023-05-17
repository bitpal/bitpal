defmodule BitPal.Backend.Monero do
  use BitPal.Backend, currency_id: :XMR
  alias BitPal.Blocks
  alias BitPal.ExtNotificationHandler
  alias BitPal.Backend.Monero.DaemonRPC
  alias BitPal.Backend.Monero.Wallet
  alias BitPal.Backend.Monero.WalletRPC
  alias BitPal.Invoices
  alias BitPal.Transactions
  require Logger

  @supervisor MoneroSupervisor
  # FIXME configurable what account we should pass our payments to
  @account 0
  @init_wallet Application.compile_env(:bitpal, [BitPal.Backend.Monero, :init_wallet], true)

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

    state =
      Enum.into(opts, %{})
      |> Map.put_new(:rpc_client, BitPal.RPCClient)
      |> Map.put_new(:sync_check_interval, 1_000)
      |> Map.put_new(:daemon_check_interval, 30_000)

    {:noreply, state, {:continue, :info}}
  end

  @impl true
  def handle_continue(:info, state) do
    case get_info(state) do
      {:ok, state} -> {:noreply, state, {:continue, :init_wallet}}
      {:error, error} -> {:stop, {:shutdown, error}, state}
    end
  end

  def handle_continue(:init_wallet, state) do
    ExtNotificationHandler.subscribe("monero:tx-notify")
    ExtNotificationHandler.subscribe("monero:block-notify")
    ExtNotificationHandler.subscribe("monero:reorg-notify")

    if @init_wallet do
      Supervisor.start_link(
        [
          Wallet.executable_child_spec()
        ],
        strategy: :one_for_one,
        name: @supervisor
      )
    end

    {:noreply, state}
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
    case get_info(state) do
      {:ok, state} -> {:noreply, state}
      {:error, error} -> {:stop, {:shutdown, error}, state}
    end
  end

  @impl true
  def handle_info({:notify, "monero:tx-notify", [txid]}, state) do
    update_tx(txid, state)
    {:noreply, state}
  end

  @impl true
  def handle_info({:notify, "monero:block-notify", _msg}, state) do
    case get_info(state) do
      {:ok, state} -> {:noreply, state}
      {:error, error} -> {:stop, {:shutdown, error}, state}
    end
  end

  @impl true
  def handle_info({:notify, "monero:reorg-notify", [new_height, split_height]}, state) do
    Logger.warn("reorg detected!: new_height: #{new_height} split_height: #{split_height}")

    # Recheck all transactions that may be affected by the reorg.
    unless Blocks.reorg(:XMR, new_height, split_height) == :no_reorg do
      for tx <- Transactions.above_or_equal_height(:XMR, split_height) do
        update_tx(tx.id, state)
      end
    end

    case get_info(state) do
      {:ok, state} -> {:noreply, state}
      {:error, error} -> {:stop, {:shutdown, error}, state}
    end
  end

  @impl true
  def handle_info({:update_tx, txid}, state) do
    update_tx(txid, state)
    {:noreply, state}
  end

  # Internal impl

  defp update_tx(txid, state) do
    {:ok, %{"transfer" => txinfo}} =
      WalletRPC.get_transfer_by_txid(state.rpc_client, txid, @account)

    update_tx_info(txinfo)
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
    |> update_sync(info)
    |> update_height(info)
    |> store_daemon_info(info)
  end

  defp update_sync(state, _) do
    # TODO update sync status
    state
  end

  # defp update_sync(state, %{"synchronized" => true}) do
  #   sync_done()
  #   Process.send_after(self(), :update_info, state.daemon_check_interval)
  #   state
  # end
  #
  # defp update_sync(state, %{
  #        "synchronized" => false,
  #        "target_height" => target_height,
  #        "height" => height
  #      }) do
  #   set_syncing({height, target_height})
  #   Process.send_after(self(), :update_info, state.sync_check_interval)
  #   state
  # end

  defp update_height(state, %{"height" => height, "top_block_hash" => hash}) do
    unless Blocks.new(:XMR, height, hash) == :not_updated do
      for tx <- Transactions.pending(:XMR) do
        update_tx(tx.id, state)
      end
    end

    state
  end

  defp store_daemon_info(state, info) do
    BackendEvents.broadcast({{:backend, :info}, %{info: info, currency_id: :XMR}})
    Map.put(state, :daemon_info, info)
  end

  defp create_info(state) do
    Map.get(state, :daemon_info, %{})
  end
end
