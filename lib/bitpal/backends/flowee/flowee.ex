defmodule BitPal.Backend.Flowee do
  @behaviour BitPal.Backend
  use GenServer
  alias BitPal.Addresses
  alias BitPal.Backend
  alias BitPal.Backend.Flowee.Connection
  alias BitPal.Backend.Flowee.Connection.Binary
  alias BitPal.Backend.Flowee.Protocol
  alias BitPal.Backend.Flowee.Protocol.Message
  alias BitPal.BCH.Cashaddress
  alias BitPal.Blocks
  alias BitPal.Cache
  alias BitPal.Invoices
  alias BitPal.Transactions
  require Logger

  @supervisor BitPal.Backend.Flowee.TaskSupervisor
  @cache BitPal.RuntimeStorage
  @bch :BCH

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # Returns the amount of satoshi to ask for. Note: This will be modified slightly so that the system
  # is able to differentiate between different transactions.
  @impl Backend
  def register(backend, invoice) do
    GenServer.call(backend, {:register, invoice})
  end

  @impl Backend
  def supported_currencies(_backend) do
    [@bch]
  end

  @impl Backend
  def configure(_backend, _opts) do
    :ok
  end

  @impl Backend
  def ready?(backend) do
    GenServer.call(backend, {:ready?})
  end

  # Address is a "bitcoincash:..." address.
  # Note: This is mainly intended for testing. Registering requests will automagically start watching addresses.
  def watch_address(address) do
    GenServer.cast(__MODULE__, {:watch, address})
  end

  # Sever API

  @impl true
  def init(opts) do
    Logger.info("Starting Flowee")

    state =
      Enum.into(opts, %{})
      |> Map.put_new(:tcp_client, BitPal.TCPClient)
      |> Map.put_new(:backend_ready, false)

    state = start_flowee(state)

    {:ok, state}
  end

  @impl true
  def handle_call({:register, invoice}, _from, state) do
    {:ok, invoice} =
      Invoices.ensure_address(invoice, fn address_index ->
        Application.fetch_env!(:bitpal, :xpub)
        |> Cashaddress.derive_address(address_index)
      end)

    {:reply, invoice, watch_address(invoice.address_id, state)}
  end

  @impl true
  def handle_call({:ready?}, _from, state) do
    r = Map.get(state, :backend_ready, false)
    {:reply, r, state}
  end

  @impl true
  def handle_cast({:set_ready}, state) do
    # Note: This is where we would broadcast "we're ready" if we need that.
    state = Map.put(state, :backend_ready, true)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:watch, address}, state) do
    {:noreply, watch_address(address, state)}
  end

  @impl true
  def handle_cast({:message, msg}, state) do
    # We got a message from Flowee, inspect it and act upon it!
    case msg do
      %Message{type: :info, data: data} ->
        on_info(Map.get(state, :hub_connection), data)

      %Message{type: :new_block, data: data} ->
        on_new_block(data)

      %Message{type: :version, data: %{version: ver}} ->
        Logger.info("Running Flowee server version: " <> ver)

      %Message{type: :subscribe_reply} ->
        # We could read the number of new subscriptions if we want to.
        nil

      %Message{type: :on_transaction, data: data} ->
        # We got notified of a transaction!
        on_transaction(data)

      %Message{type: :on_double_spend, data: data} ->
        # We got notified of a double spend...
        on_double_spend(data)

      %Message{type: :block, data: data} ->
        on_block(Map.get(state, :hub_connection), data)

      %Message{type: :pong} ->
        # Just ignore it
        nil

      _ ->
        Logger.info("Unknown message from Flowee: " <> Kernel.inspect(msg))
    end

    {:noreply, state}
  end

  # Send PING messages to Flowee periodically (approx once a minute). Otherwise it will deconnect from us!
  @impl true
  def handle_info({:send_ping}, state = %{hub_connection: conn}) do
    Protocol.send_ping(conn)
    enqueue_ping(state)
    {:noreply, state}
  end

  @impl true
  def handle_info({:send_ping}, state) do
    {:noreply, state}
  end

  # Handle restarts of the Flowee process.
  @impl true
  def handle_info({:DOWN, _monitor, :process, pid, _reason}, state) do
    if pid == state[:hub_pid] do
      # The Flowee process died. Close our connection and restart it!
      Connection.close(state[:hub_connection])
      {:noreply, start_hub(state)}
    else
      # Something else happened.
      {:noreply, state}
    end
  end

  # Called when we need to wait for Flowee to become ready.
  @impl true
  def handle_info(:wait_for_flowee, state) do
    c = Map.get(state, :hub_connection)

    # Ask Flowee for its status again. This will re-check if it is ready and act appropriately.
    Protocol.send_blockchain_info(c)
    {:noreply, state}
  end

  # Called when a new block has been mined (regardless of whether or not it contains one of our transactions)
  defp on_new_block(%{height: height}) do
    Logger.info("New block. Height is now: " <> inspect(height))
    # Save the block height. This means that during recovery, we don't have to examine this block.
    Blocks.new_block(@bch, height)
  end

  # Called when we received a new transaction.
  # Note: We get the "transaction visible" immediately when we subscribe,
  # as long as it is not accepted into a block.
  # If we have `height` then the transaction is confirmed, otherwise it's in the mempool.
  defp on_transaction(%{txid: txid, height: height, outputs: outputs}) do
    Transactions.confirmed(binary_to_string(txid), filter_outputs(outputs), height)
  end

  defp on_transaction(%{txid: txid, outputs: outputs}) do
    Transactions.seen(binary_to_string(txid), filter_outputs(outputs))
  end

  # Called when we received a double spend.
  defp on_double_spend(%{txid: txid, outputs: outputs}) do
    Transactions.double_spent(binary_to_string(txid), filter_outputs(outputs))
  end

  defp filter_outputs(outputs) do
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

  # Start watching an address. "address" is a "bitcoincash:..." address.
  defp watch_address(address, state = %{hub_connection: c}) do
    subscribe_addr(c, address)
    state
  end

  defp watch_address(_address, state), do: state

  # (re)start our connection to Flowee
  def start_flowee(state) do
    Task.Supervisor.start_link(name: @supervisor)

    # Connect to Flowee: The Hub, and start listening for messages from it.
    start_hub(state)
  end

  # Connection to The Hub.
  defp start_hub(state) do
    c = Connection.connect(state.tcp_client)
    state = Map.put(state, :hub_connection, c)
    state = Map.put(state, :backend_ready, false)

    {:ok, pid} =
      Task.Supervisor.start_child(
        @supervisor,
        __MODULE__,
        :receive_messages,
        [c]
      )

    # NOTE register pid in ProcessRegistry instead?
    state = Map.put(state, :hub_pid, pid)

    # Monitor it for crashes.
    Process.monitor(pid)

    # Start sending pings
    enqueue_ping(state)

    # Supscribe to invoices we should be tracking
    Enum.each(Invoices.active_addresses(@bch), fn address ->
      subscribe_addr(c, address)
    end)

    # Query the current status of the blockchain. This is so that we can update the current height
    # of the blockchain and to look for confirmations for transactions we might have missed.
    # Note: We don't want to subscribe for block notifications before this, since it might cause
    # us to update the block height "too early".
    Protocol.send_blockchain_info(c)

    state
  end

  # Called by the recovery logic when it is done. This is the final parts of startup.
  defp finish_startup(connection) do
    # Mark ourself as "done".
    GenServer.cast(self(), {:set_ready})

    # Also, subscribe for block notifications now.
    Protocol.send_block_subscribe(connection)
  end

  # Called when we received information from the blockend. This is done during startup of the Flowee backend.
  defp on_info(connection, %{blocks: height, verification_progress: progress}) do
    Logger.info("Startup: new block height: #{inspect(height)}")

    # Do we need to recover any blocks?
    if recover_blocks_until(connection, height) do
      # If any recovery needed, we should not do anything more now.
    else
      # Done, update the block height (might already have been done, but does not hurt to do an extra time).
      Blocks.set_block_height(@bch, height)

      # See if Flowee is up to date.
      if progress < 0.9999 do
        # No, we need to wait for it... Poll it every ~30 seconds or so.
        Process.send_after(self(), :wait_for_flowee, 30 * 1000);
      else
        finish_startup(connection)
      end
    end
  end

  # See if we need to recover some blocks. Returns "true" if we initiated any recovery.
  defp recover_blocks_until(connection, height) do
    case Blocks.fetch_block_height(@bch) do
      {:ok, prev_height} ->
        recover_blocks_between(connection, prev_height, height)

      _ ->
        # No previous block height, nothing we can recover from.
        false
    end
  end

  # See if we need to recover blocks in the interval (old, new). Returns "true" if we initiated recovery.
  defp recover_blocks_between(connection, checked, current) do
    if (checked < current) do
      # Check block "checked + 1" and see if we have something to do there.
      active = Invoices.active_addresses(@bch)
      if Enum.empty?(active) do
        # No addresses. Nothing to do, even if we are behind.
        false
      else
        # We have addresses, send a request and see if we missed something.
        hashes = Enum.map(active, fn x -> {:address, create_addr_hash(x)} end)
        Protocol.send_get_block(connection, {:height, checked + 1}, [:txid, :amounts, :outputHash], hashes)
      end
    else
      # Nothing to do.
      false
    end
  end

  # Reply from a "get_block" question.
  defp on_block(connection, %Message{data: %{height: height, transactions: transactions}}) do
    # Look at all transactions.
    Enum.each(transactions, fn %{outputs: outputs, txid: txid} ->
      Transactions.confirmed(binary_to_string(txid), filter_info_outputs(outputs), height)
    end)

    # Now, we can save that we have processed this block. If we do it any earlier, we might miss
    # blocks in case we crash during recovery.
    Blocks.set_block_height(@bch, height)

    # Send a new info message. This will trigger "on_info" again, and cause recovery to continue.
    Protocol.send_blockchain_info(connection)
  end

  # Version of "filter_info_outputs" for the format from "on_block_info".
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

  defp enqueue_ping(state) do
    timeout = Map.get(state, :ping_timeout, :timer.minutes(1))
    :timer.send_after(timeout, self(), {:send_ping})
  end

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
    Logger.info("Subscribed to new wallet: " <> inspect(addr))
    Protocol.send_address_subscribe(conn, hash)
  end

  # Receive messages. Executed in another process, so it is OK to block here.
  def receive_messages(c) do
    msg = Protocol.recv(c)
    GenServer.cast(__MODULE__, {:message, msg})

    # Keep on working!
    receive_messages(c)
  end
end
