defmodule BitPal.Backend.Monero do
  use BitPal.Backend, currency_id: :XMR
  alias BitPal.Backend.Monero.DaemonRPC
  alias BitPal.Backend.Monero.Wallet
  alias BitPal.Backend.Monero.WalletSupervisor
  alias BitPal.Blocks
  alias BitPal.Invoices
  alias BitPal.ExtNotificationHandler
  alias BitPal.Stores
  require Logger

  # Client API

  @impl Backend
  def assign_address(backend, invoice) do
    GenServer.call(backend, {:assign_address, invoice})
  end

  @impl Backend
  def assign_payment_uri(_backend, invoice) do
    Invoices.assign_payment_uri(invoice, %{
      prefix: "monero",
      decimal_amount_key: "tx_amount",
      description_key: "tx_description",
      recipient_name_key: "recipient_name"
    })
  end

  @impl Backend
  def watch_invoice(_backend, _invoice) do
    # No need to manually watch addresses as the wallet will do this for us.
    :ok
  end

  @impl Backend
  def update_address(backend, invoice) do
    GenServer.call(backend, {:update_address, invoice})
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

        {:noreply, state, {:continue, :init_wallets}}

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
  def handle_continue(:init_wallets, state) do
    WalletSupervisor.start_link(Map.take(state, [:log_level]) |> Enum.into([]))

    # Immediately start wallets for all stores with an (hopefully) valid address key.
    # - To identify transactions/confirmations that may have happened while we were offline.
    # - To make the first invoice creation fast (otherwise starting up the wallet will cause a noticeable lag).
    for {store, key} <- Stores.with_address_key(:XMR) do
      viewkey = key.data[:viewkey]

      if viewkey != nil && viewkey != "" do
        WalletSupervisor.ensure_wallet(store.id, wallet_opts(state))
      end
    end

    {:noreply, state, {:continue, :finalize_setup}}
  end

  @impl true
  def handle_continue(:finalize_setup, state) do
    {:noreply, update_sync(state)}
  end

  # I'm not sure about this actually...
  # This only gets options from the backend process
  # while serializing all requests.

  @impl true
  def handle_call({:assign_address, invoice}, _from, state) do
    res =
      case WalletSupervisor.ensure_wallet(
             invoice.store_id,
             wallet_opts(state)
           ) do
        {:ok, wallet} ->
          Wallet.assign_address(wallet, invoice)

        err ->
          err
      end

    {:reply, res, state}
  end

  @impl true
  def handle_call({:update_address, invoice}, _from, state) do
    case WalletSupervisor.fetch_wallet(invoice.store_id) do
      {:ok, wallet} ->
        Wallet.update_address(wallet, invoice)

      err ->
        err
    end

    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:get_info, _from, state) do
    {:reply, create_info(state), state}
  end

  @impl true
  def handle_info(:update_info, state) do
    {:ok, state} = update_info(state)
    Process.send_after(self(), :update_info, state.daemon_check_interval)
    {:noreply, state}
  end

  @impl true
  def handle_info({:notify, "monero:block-notify", msg}, state) do
    Logger.info("block notify: #{inspect(msg)}")
    {:ok, state} = update_info(state)
    {:noreply, state}
  end

  @impl true
  def handle_info({:notify, "monero:reorg-notify", [new_height, split_height]}, state) do
    Logger.warn("reorg detected!: new_height: #{new_height} split_height: #{split_height}")
    Blocks.reorg(:XMR, new_height, split_height)
    {:noreply, state}
  end

  @impl true
  def handle_info(:update_sync, state) do
    {:noreply, update_sync(state)}
  end

  @impl true
  def terminate(reason, _state) do
    # Ensure that all wallets are closed together with the backend,
    # which isn't always a guarantee.
    try do
      DynamicSupervisor.stop(WalletSupervisor, reason)
    catch
      :exit, _ -> :ok
    end
  end

  # Internal impl

  @spec update_info(map) :: {:ok, map} | {:error, term}
  defp update_info(state) do
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
    Blocks.new(:XMR, height, hash)
    state
  end

  defp store_daemon_info(state, info) do
    BackendEvents.broadcast({{:backend, :info}, %{info: info, currency_id: :XMR}})
    Map.put(state, :daemon_info, info)
  end

  defp update_sync(state) do
    {:ok, %{"height" => daemon_height, "target_height" => target_height}} =
      DaemonRPC.sync_info(state.rpc_client)

    if target_height == 0 do
      # Wait until wallet and daemon are connected before we accept notifies.
      # Protects against race conditions where we try to make RPC calls that will
      # fail because they aren't ready yet.
      # Since we do this in continue that won't happen anyway, but this way we ignore
      # notifies that we shouldn't act on anyway.
      ExtNotificationHandler.subscribe("monero:block-notify")
      ExtNotificationHandler.subscribe("monero:reorg-notify")

      {:ok, state} = update_info(state)

      # We should poll regularly even though we also use notifications.
      Process.send_after(self(), :update_info, state.daemon_check_interval)

      sync_done()

      state
    else
      set_syncing({daemon_height, target_height})

      Process.send_after(self(), :update_sync, state.sync_check_interval)

      state
    end
  end

  defp wallet_opts(state) do
    Map.take(state, [:rpc_client, :reconnect_timeout, :log_level])
    |> Enum.into([])
  end

  defp create_info(state) do
    Map.get(state, :daemon_info, %{})
  end
end
