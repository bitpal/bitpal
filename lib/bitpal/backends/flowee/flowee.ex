defmodule BitPal.Backend.Flowee do
  @behaviour BitPal.Backend
  use GenServer
  alias BitPal.Addresses
  alias BitPal.Backend
  alias BitPal.BackendStatusManager
  alias BitPal.Backend.Flowee.Connection
  alias BitPal.Backend.Flowee.Connection.Binary
  alias BitPal.Backend.Flowee.Protocol
  alias BitPal.Backend.Flowee.Protocol.Message
  alias BitPal.BCH.Cashaddress
  alias BitPal.Blocks
  alias BitPal.Cache
  alias BitPal.Invoices
  alias BitPal.ProcessRegistry
  alias BitPal.Transactions
  require Logger

  @supervisor BitPal.Backend.Flowee.TaskSupervisor
  @status_manager BitPal.Backend.Flowee.StatusManager
  @cache BitPal.RuntimeStorage
  @bch :BCH

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Start watching an "bitcoincash:..." address.
  Mostly used for testing as addresses will be watced when an invoice is created.
  """
  def watch_address(address) do
    GenServer.call(__MODULE__, {:watch, address})
  end

  # Returns the amount of satoshi to ask for. Note: This will be modified slightly so that the system
  # is able to differentiate between different transactions.
  @impl Backend
  def register(backend, invoice) do
    GenServer.call(backend, {:register, invoice})
  end

  @impl Backend
  def supported_currency(_backend), do: @bch

  @impl Backend
  def configure(_backend, _opts), do: :ok

  @impl Backend
  def status(_backend), do: BackendStatusManager.status(@status_manager)

  @impl Backend
  def start(_backend), do: :ok

  @impl Backend
  def stop(_backend), do: :ok

  # Sever API

  @impl true
  def init(opts) do
    Logger.info("Starting Flowee")

    state =
      Enum.into(opts, %{})
      |> Map.put_new(:tcp_client, BitPal.TCPClient)
      |> Map.put_new(:sync_check_interval, 1_000)

    Registry.register(
      ProcessRegistry,
      Backend.via_tuple(@bch),
      __MODULE__
    )

    Task.Supervisor.start_link(name: @supervisor)

    state = start_hub(state)

    {:ok, state}
  end

  @impl true
  def handle_call({:register, invoice}, _from, state) do
    registered =
      Invoices.ensure_address(invoice, fn %{key: xpub, index: address_index} ->
        Cashaddress.derive_address(xpub, address_index)
      end)

    case registered do
      {:ok, invoice} ->
        {:reply, {:ok, invoice}, watch_address(invoice.address_id, state)}

      err ->
        {:reply, err, state}
    end
  end

  @impl true
  def handle_call({:watch, address}, _, state) do
    {:noreply, watch_address(address, state)}
  end

  @impl true
  def handle_cast({:message, %Message{type: type, data: data}}, state) do
    {:noreply, handle_message(type, data, state)}
  end

  # Send PING messages to Flowee periodically (approx once a minute). Otherwise it will deconnect from us!
  @impl true
  def handle_info(:send_ping, state = %{hub_connection: conn}) do
    Protocol.send_ping(conn)
    enqueue_ping(state)
    {:noreply, state}
  end

  @impl true
  def handle_info(:send_ping, state) do
    {:noreply, state}
  end

  # Handle restarts of the Flowee process.
  @impl true
  def handle_info({:DOWN, _monitor, :process, pid, _reason}, state) do
    if pid == state[:recieve_pid] do
      # The Flowee process died. Close our connection and restart it!
      Connection.close(state[:hub_connection])
      {:noreply, start_hub(state)}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(:send_blockchain_info, state = %{hub_connection: c}) do
    Protocol.send_blockchain_info(c)
    {:noreply, state}
  end

  # Startup and recovery

  defp start_hub(state) do
    BackendStatusManager.start_link(
      name: @status_manager,
      currency_id: @bch,
      rate_limit: state[:sync_check_interval]
    )

    case Connection.connect(state.tcp_client) do
      {:ok, c} ->
        start_hub(state, c)

      {:error, error} ->
        Logger.debug("Error connecting to flowee: #{inspect(error)}")
        BackendStatusManager.error(@status_manager, error)
        state
    end
  end

  defp start_hub(state, c) do
    # FIXME should get version as well

    # Start listening to messages from the hub.
    {:ok, recieve_pid} =
      Task.Supervisor.start_child(
        @supervisor,
        __MODULE__,
        :receive_messages,
        [c]
      )

    # Monitor it for crashes.
    Process.monitor(recieve_pid)

    # Start sending pings
    enqueue_ping(state)

    # Supscribe to invoices we should be tracking
    Enum.each(Addresses.all_active(@bch), fn address ->
      subscribe_addr(c, address)
    end)

    # Query the current status of the blockchain. This is so that we can update the current height
    # of the blockchain and to look for confirmations for transactions we might have missed.
    # Note: We don't want to subscribe for block notifications before this, since it might cause
    # us to update the block height "too early".
    Protocol.send_blockchain_info(c)

    Map.merge(state, %{hub_connection: c, recieve_pid: recieve_pid})
  end

  # Messages from Flowee

  defp handle_message(:get_blockchain_info_reply, info, state) do
    state
    |> Map.put(:blockchain_info, info)
    |> recover_blocks_if_needed()
    |> delayed_send_get_info_if_needed()
  end

  defp handle_message(:get_block_reply, %{height: height, transactions: transactions}, state) do
    # Look at all transactions.
    Enum.each(transactions, fn %{outputs: outputs, txid: txid} ->
      Transactions.confirmed(binary_to_string(txid), filter_info_outputs(outputs), height)
    end)

    # Now, we can save that we have processed this block. If we do it any earlier, we might miss
    # blocks in case we crash during recovery.
    # Even if we could skip this during recovery, it's a better user experience to save the recovery state
    # if we abort Flowee in the middle.
    Blocks.set_block_height(@bch, height)

    continue_block_recovery(state, height)
  end

  defp handle_message(:version_reply, %{version: ver}, state) do
    Logger.info("Running Flowee server version: " <> ver)
    state
  end

  defp handle_message(:subscribe_reply, _data, state) do
    # We could read the number of new subscriptions if we want to.
    state
  end

  defp handle_message(:new_block_on_chain, %{height: height}, state) do
    Logger.debug("New #{@bch} block. Height is now: #{height}")
    # Save the block height. This means that during recovery, we don't have to examine this block.
    Blocks.new_block(@bch, height)
    state
  end

  defp handle_message(:blocks_removed, data, state) do
    Logger.warn("Reorg detected! #{inspect(data)}")
    state
  end

  # Called when we received a new transaction.
  # Note: We get the "transaction visible" immediately when we subscribe,
  # as long as it is not accepted into a block.
  # If we have `height` then the transaction is confirmed, otherwise it's in the mempool.
  defp handle_message(:transaction_found, %{txid: txid, height: height, outputs: outputs}, state) do
    Transactions.confirmed(binary_to_string(txid), filter_tx_outputs(outputs), height)
    state
  end

  defp handle_message(:transaction_found, %{txid: txid, outputs: outputs}, state) do
    Transactions.seen(binary_to_string(txid), filter_tx_outputs(outputs))
    state
  end

  defp handle_message(:double_spend_found, %{txid: txid, outputs: outputs}, state) do
    Transactions.double_spent(binary_to_string(txid), filter_tx_outputs(outputs))
    state
  end

  defp handle_message(:pong, _data, state) do
    # Just ignore it
    state
  end

  defp handle_message(type, data, state) do
    Logger.error("Unknown message from Flowee: #{inspect(type)} data: #{inspect(data)}")
    state
  end

  # Block recovery

  defp recover_blocks_if_needed(state = %{blockchain_info: %{blocks: height}}) do
    case Blocks.fetch_block_height(@bch) do
      {:ok, processed_height} when processed_height < height ->
        recover_blocks_between(state, processed_height, height)

      _ ->
        # No height yet, so nothing to recover.
        Blocks.set_block_height(@bch, height)
        state
    end
  end

  defp recover_blocks_between(state, processed_height, target_height) do
    Logger.debug("#{@bch} recover blocks between #{processed_height} #{target_height}")

    active = Addresses.all_active(@bch)

    if Enum.empty?(active) do
      # No addresses so nothing to recover.
      Blocks.set_block_height(@bch, target_height)
      BackendStatusManager.ready(@status_manager)
      state
    else
      # We have addresses, send a request and see if we missed something.
      # This sets up the filters for Flowee, but following requests can just reuse it until we've
      # reached `target_height`.
      hashes = Enum.map(active, fn x -> {:address, create_addr_hash(x)} end)

      Protocol.send_get_block(
        state.hub_connection,
        {:height, processed_height + 1},
        [:txid, :amounts, :outputHash],
        hashes
      )

      BackendStatusManager.recovering(@status_manager, processed_height, target_height)

      state
      |> Map.put(:recover_target, target_height)
    end
  end

  defp continue_block_recovery(state = %{recover_target: target_height}, current_height) do
    if target_height == current_height do
      # Recovery is completed, but we need to ask for info again to see
      # if there was a new block during recovery that we missed.
      Protocol.send_blockchain_info(state.hub_connection)

      state
      |> Map.delete(:recover_target)
    else
      BackendStatusManager.recovering(@status_manager, current_height, target_height)

      Protocol.send_get_block(
        state.hub_connection,
        {:height, current_height + 1},
        [:txid, :amounts, :outputHash],
        :reuse
      )

      state
    end
  end

  defp delayed_send_get_info_if_needed(state = %{recover_target: _}) do
    # We're still in recovery, need to first wait for it to be completed.
    state
  end

  defp delayed_send_get_info_if_needed(
         state = %{blockchain_info: %{verification_progress: progress}}
       ) do
    if progress < 0.9999 do
      # No, we need to wait for it... Poll it for updates.
      Process.send_after(self(), :blockchain_info, state[:sync_check_interval])

      BackendStatusManager.syncing(@status_manager, progress)
    else
      # Mark ready here for recovering as well to avoid a
      #   :recovering -> :ready -> :syncing
      # loop.
      BackendStatusManager.ready_if_syncing_or_recovering(@status_manager)
    end

    state
  end

  # Utils

  defp filter_tx_outputs(outputs) do
    Enum.flat_map(outputs, fn
      {%{data: address_hash}, amount} ->
        # Only accept hashes that we've seen before, and thus are watching
        with {:ok, address} <- fetch_hash_to_addr(address_hash),
             true <- Addresses.exists?(address) do
          # Also transform to expected values
          [{address, Money.new(amount, @bch)}]
        else
          _ -> []
        end
    end)
  end

  # Version of "filter_info_outputs" for the format from "get_blockchain_info".
  defp filter_info_outputs(outputs) do
    Enum.flat_map(outputs, fn %{amount: amount, outputHash: hash} ->
      with {:ok, address} <- fetch_hash_to_addr(hash),
           true <- Addresses.exists?(address) do
        [{address, Money.new(amount, @bch)}]
      else
        _ -> []
      end
    end)
  end

  # Start watching an address. "address" is a "bitcoincash:..." address.
  defp watch_address(address, state = %{hub_connection: c}) do
    subscribe_addr(c, address)
    state
  end

  defp watch_address(_address, state), do: state

  defp fetch_hash_to_addr(address_hash) do
    Cache.fetch(@cache, {:bch_hash2addr, address_hash})
  end

  # Convert a "bitcoin:..." address to what is needed by Flowee.
  defp create_addr_hash(address) do
    Cache.get_or_put_lazy(@cache, {:bch_addr2hash, address}, fn ->
      hash =
        address
        |> Cashaddress.decode_cash_url()
        |> Cashaddress.create_hashed_output_script()

      Cache.put(@cache, {:bch_hash2addr, hash}, address)
      hash
    end)
  end

  defp binary_to_string(%Binary{data: data}) do
    Cashaddress.binary_to_hex(data)
  end

  defp subscribe_addr(conn, addr) do
    hash = create_addr_hash(addr)
    Logger.debug("Subscribed to new #{@bch} wallet: " <> inspect(addr))
    Protocol.send_address_subscribe(conn, hash)
  end

  defp enqueue_ping(state) do
    timeout = Map.get(state, :ping_timeout, :timer.minutes(1))
    :timer.send_after(timeout, self(), :send_ping)
  end

  # Receive messages. Executed in another process, so it is OK to block here.
  def receive_messages(c) do
    msg = Protocol.recv!(c)
    GenServer.cast(__MODULE__, {:message, msg})

    # Keep on working!
    receive_messages(c)
  end
end
