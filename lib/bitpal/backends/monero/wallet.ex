defmodule BitPal.Backend.Monero.Wallet do
  use GenServer
  alias BitPal.Addresses
  alias BitPal.Backend.Monero.Settings
  alias BitPal.Backend.Monero.WalletRPC
  alias BitPal.BlockchainEvents
  alias BitPal.Blocks
  alias BitPal.ExtNotificationHandler
  alias BitPal.Files
  alias BitPal.Invoices
  alias BitPal.ProcessRegistry
  alias BitPal.Transactions
  alias BitPal.PortsHandler
  require Logger

  @start_wallet Application.compile_env(:bitpal, [BitPal.Backend.Monero, :init_wallet], true)

  @rpc_password ""

  def assign_address(wallet, invoice) do
    GenServer.call(wallet, {:assign_address, invoice})
  end

  def update_address(wallet, invoice) do
    GenServer.call(wallet, {:update_address, invoice})
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def child_spec(opts) do
    store_id = Keyword.fetch!(opts, :store_id)

    %{
      id: store_id,
      # restart: :transient,
      restart: :temporary,
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  @impl true
  def init(opts) do
    store_id = Keyword.fetch!(opts, :store_id)
    Registry.register(ProcessRegistry, via_tuple(store_id), store_id)

    if log_level = opts[:log_level] do
      Logger.put_process_level(self(), log_level)
    end

    state =
      Enum.into(opts, %{
        port: PortsHandler.assign_port(),
        rpc_client: BitPal.RPCClient
      })

    {:ok, state, {:continue, :start_wallet}}
  end

  @impl true
  def handle_continue(:start_wallet, state) do
    if @start_wallet do
      MuonTrap.Daemon.start_link(executable(), executable_options(state))
    end

    {:noreply, state, {:continue, :connect_wallet}}
  end

  @impl true
  def handle_continue(:connect_wallet, state) do
    case WalletRPC.get_version(rpc_ref(state)) do
      {:ok, %{"version" => version}} ->
        state =
          state
          |> Map.put(:version, version)
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
    ExtNotificationHandler.subscribe("monero:tx-notify")
    BlockchainEvents.subscribe(:XMR)
    check_active_addresses(state)
    {:noreply, state}
  end

  @impl true
  def handle_call({:assign_address, invoice}, _from, state) do
    {:ok, %{"address" => address_id, "address_index" => index}} =
      WalletRPC.create_address(rpc_ref(state), state.address_key.data.account)

    # FIXME what if the address is already taken?
    with {:ok, address} <- Addresses.register(state.address_key, address_id, index),
         {:ok, invoice} <- Invoices.assign_address(invoice, address) do
      {:reply, {:ok, invoice}, state}
    else
      err ->
        {:reply, err, state}
        err
    end
  end

  @impl true
  def handle_call({:update_address, invoice}, _from, state) do
    check_address(state, invoice.address)
    {:reply, :ok, state}
  end

  @impl true
  def handle_info({:notify, "monero:tx-notify", [txid, store_id]}, state) do
    if match_store?(state.store_id, store_id) do
      Logger.info("tx notify: #{txid}")
      update_tx(txid, state)
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({{:block, :new}, _}, state) do
    check_active_addresses(state)
    {:noreply, state}
  end

  @impl true
  def handle_info({{:block, :reorg}, _}, state) do
    # NOTE It's possible that we'll miss already paid transactions if we only check active addresses.
    check_active_addresses(state, reorg: true)
    {:noreply, state}
  end

  defp update_tx(txid, state) do
    case WalletRPC.get_transfer_by_txid(
           rpc_ref(state),
           txid,
           state.address_key.data.account
         ) do
      {:ok, %{"transfer" => txinfo}} ->
        update_tx_info(txinfo)

      error ->
        Logger.error("Failed to get tx: `#{txid}`: #{inspect(error)}")
    end
  end

  defp check_address(state, address) do
    get_transfers(state, [address.address_index])
  end

  defp check_active_addresses(state, opts \\ []) do
    address_indices =
      Enum.map(Addresses.all_active(:XMR), fn a ->
        a.address_index
      end)

    get_transfers(state, address_indices, opts)
  end

  defp get_transfers(state, address_indices, opts \\ []) do
    {:ok, res} =
      WalletRPC.get_transfers(
        rpc_ref(state),
        state.address_key.data.account,
        address_indices
      )

    update_txs(res["in"], opts)
    update_txs(res["pending"], opts)
    update_txs(res["failed"], opts)
    update_txs(res["pool"], opts)
  end

  defp executable do
    System.find_executable("monero-wallet-rpc")
  end

  defp executable_options(state) do
    wallet_file = Files.wallet_file(state.store_id, :monero, Settings.net())

    if File.exists?(wallet_file) do
      open_wallet_args(wallet_file, state)
    else
      create_wallet_args(wallet_file, state)
    end
  end

  defp open_wallet_args(wallet_file, state) do
    Logger.info("Opening Monero wallet")
    Logger.info("  filename: #{wallet_file}")

    ["--wallet-file", wallet_file] ++ common_options(state)
  end

  defp create_wallet_args(wallet_file, state) do
    # Use --generate-from-json to launch wallet-rpc with a new wallet file
    {fd, json_file} = Temp.open!("#{state.store_id}-xmr-wallet.json")

    %{address: address, viewkey: viewkey} = state.address_key.data
    restore_height = Blocks.fetch_height!(:XMR)

    :ok =
      IO.write(
        fd,
        Jason.encode!(%{
          address: address,
          viewkey: viewkey,
          version: 1,
          filename: wallet_file,
          scan_from_height: restore_height
        })
      )

    :ok = File.close(fd)

    Logger.info("Generating new Monero wallet")
    Logger.info("  filename: #{wallet_file}")
    Logger.info("  address: #{address}")
    Logger.info("  viewkey: #{viewkey}")
    Logger.info("  restore_height: #{restore_height}")

    File.mkdir_p!(Path.dirname(wallet_file))
    ["--generate-from-json", json_file] ++ common_options(state)
  end

  defp common_options(state) do
    net_option() ++
      [
        "--daemon-address",
        Settings.daemon_address(),
        "--rpc-bind-port",
        "#{state.port}",
        "--disable-rpc-login",
        "--log-file",
        "/var/log/monero/bitpal.log",
        "--log-level",
        "2",
        "--password",
        @rpc_password,
        "--trusted-daemon",
        # "--non-interactive",
        "--tx-notify",
        "#{Files.notify_path()} monero:tx-notify %s #{state.store_id}"
      ]
  end

  defp net_option do
    case Settings.net() do
      :stagenet -> ["--stagenet"]
      :testnet -> ["--testnet"]
      _ -> []
    end
  end

  defp update_txs(txs, opts) when is_list(txs) do
    for tx <- txs do
      update_tx_info(tx, opts)
    end
  end

  defp update_txs(_, _), do: nil

  defp update_tx_info(
         %{
           "address" => address,
           "amount" => amount,
           "double_spend_seen" => double_spend_seen,
           "height" => height,
           "txid" => txid,
           "type" => type,
           "unlock_time" => unlock_time
         },
         opts \\ []
       ) do
    outputs = [{address, Money.new(amount, :XMR)}]

    reasonable_unlock = reasonable_unlock_time?(unlock_time)

    Transactions.update(txid,
      outputs: outputs,
      height: height,
      double_spent: double_spend_seen,
      failed: type == "failed" || !reasonable_unlock,
      reorg: Keyword.get(opts, :reorg, false)
    )

    :ok
  end

  # unlock_time not set
  def reasonable_unlock_time?(0) do
    true
  end

  # Integer values less than 500,000,000 are interpreted as absolute block height.
  def reasonable_unlock_time?(unlock_time) when unlock_time < 500_000_000 do
    unlock_time <= Blocks.fetch_height!(:XMR) + Settings.acceptable_unlock_time_blocks()
  end

  # Values greater than or equal to 500,000,000 are interpreted as an absolute Unix epoch timestamp.
  def reasonable_unlock_time?(unlock_time) when unlock_time >= 500_000_000 do
    last_valid =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.truncate(:second)
      |> NaiveDateTime.add(Settings.acceptable_unlock_time_minutes(), :minute)

    unlock_dt = NaiveDateTime.add(~N[1970-01-01 00:00:00], unlock_time)

    NaiveDateTime.compare(unlock_dt, last_valid) != :gt
  rescue
    _ ->
      # Very large integer values cannot be converted to a datetime and will crash "add"
      false
  end

  defp rpc_ref(state), do: {state.rpc_client, state.port}

  defp match_store?(s1, s1), do: true

  defp match_store?(s1, s2) when is_binary(s2) do
    s1 == String.to_integer(s2)
  rescue
    _ -> false
  end

  @spec via_tuple(Store.id()) :: {:via, Registry, any}
  def via_tuple(store_id) do
    ProcessRegistry.via_tuple({__MODULE__, store_id})
  end
end
