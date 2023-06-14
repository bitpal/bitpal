defmodule BitPal.Backend.Flowee do
  @moduledoc """
  Support for Flowee the hub.

  IMPORTANT to note that as of the May 2023 Bitcoin Cash upgrade, the hub is no longer
  up to date with the consensus rules, so this plugin should not be used live anymore.
  """

  use BitPal.Backend, currency_id: :BCH
  alias BitPal.Addresses
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

  @cache BitPal.RuntimeStorage

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
  def update_address(_backend, _invoice) do
    # Shouldn't be necessary as we're subscribing to addresses and getting notifications?
    :ok
  end

  @impl Backend
  def info(backend), do: GenServer.call(backend, :info)

  @impl Backend
  def refresh_info(backend), do: GenServer.call(backend, :poll_info)

  # Sever API

  @impl true
  def handle_continue(:init, opts) do
    # Prevent us from accidentally using Flowee.
    raise "Flowee not up to date with BCH consensus rules"

    Logger.notice("Starting Flowee backend")

    state =
      Enum.into(opts, %{})
      |> Map.put_new(:tcp_client, BitPal.TCPClient)
      |> Map.put_new(:sync_check_interval, 1_000)

    {:noreply, state, {:continue, :connect}}
  end

  @impl true
  def handle_continue(:connect, state) do
    case Connection.connect(state.tcp_client) do
      {:ok, c} ->
        {:noreply, Map.merge(state, %{hub_connection: c}), {:continue, :listen}}

      {:error, error} ->
        {:stop, {:shutdown, error}, state}
    end
  end

  @impl true
  def handle_continue(:listen, state = %{hub_connection: c}) do
    Task.start_link(__MODULE__, :receive_messages, [c])

    # Start sending pings
    enqueue_ping(state)

    # Subscribe to invoices we should be tracking
    Enum.each(Addresses.all_active_ids(:BCH), fn address ->
      subscribe_addr(c, address)
    end)

    # So we can track the Flowee version we're running.
    Protocol.send_version(c)

    # Query the current status of the blockchain. This is so that we can update the current height
    # of the blockchain and to look for confirmations for transactions we might have missed.
    # Note: We don't want to subscribe for block notifications before this, since it might cause
    # us to update the block height "too early".
    Protocol.send_blockchain_info(c)

    {:noreply, state}
  end

  @impl true
  def handle_call({:watch_invoice, invoice}, _, state = %{hub_connection: c}) do
    subscribe_addr(c, invoice.address_id)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:watch_invoice, _address}, _, state) do
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:info, _from, state) do
    {:reply, create_info(state), state}
  end

  @impl true
  def handle_call(:poll_info, _from, state = %{hub_connection: c}) do
    Protocol.send_blockchain_info(c)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:poll_info, _from, state) do
    {:reply, {:error, :not_connected}, state}
  end

  @impl true
  def handle_call({:connection_error, error}, _from, state) do
    Logger.error("Connection error from Flowee: #{inspect(error)}")
    {:stop, {:shutdown, {:connection, error}}, state}
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

  @impl true
  def handle_info(:send_blockchain_info, state = %{hub_connection: c}) do
    Protocol.send_blockchain_info(c)
    {:noreply, state}
  end

  # Messages from Flowee

  defp handle_message(:get_blockchain_info_reply, info, state) do
    state
    |> Map.put(:blockchain_info, info)
    |> recover_blocks_if_needed()
    |> delayed_send_get_info_if_needed()
    |> broadcast_info()
  end

  defp handle_message(:get_block_reply, %{height: height, transactions: transactions}, state) do
    # Look at all transactions.
    Enum.each(transactions, fn %{outputs: outputs, txid: txid} ->
      Transactions.update(binary_to_string(txid),
        outputs: filter_info_outputs(outputs),
        height: height
      )
    end)

    # Now, we can save that we have processed this block. If we do it any earlier, we might miss
    # blocks in case we crash during recovery.
    # Even if we could skip this during recovery, it's a better user experience to save the recovery state
    # if we abort Flowee in the middle.
    Blocks.new(:BCH, height)

    # NOTE if any tx is found, we should recheck open invoices.
    continue_block_recovery(state, height)
  end

  defp handle_message(:version_reply, %{version: ver}, state) do
    Logger.info("Running Flowee version: " <> ver)
    Map.put(state, :version, ver)
  end

  defp handle_message(:subscribe_reply, _data, state) do
    # We could read the number of new subscriptions if we want to.
    state
  end

  defp handle_message(:new_block_on_chain, %{height: height}, state) do
    Logger.debug("New #{:BCH} block. Height is now: #{height}")
    # Save the block height. This means that during recovery, we don't have to examine this block.
    Blocks.new(:BCH, height)
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
    Transactions.update(binary_to_string(txid),
      height: height,
      outputs: filter_tx_outputs(outputs)
    )

    state
  end

  defp handle_message(:transaction_found, %{txid: txid, outputs: outputs}, state) do
    Transactions.update(binary_to_string(txid), outputs: filter_tx_outputs(outputs))
    state
  end

  defp handle_message(:double_spend_found, %{txid: txid, outputs: outputs}, state) do
    Transactions.update(binary_to_string(txid),
      outputs: filter_tx_outputs(outputs),
      double_spent: true
    )

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
    case Blocks.fetch_height(:BCH) do
      {:ok, processed_height} when processed_height < height ->
        recover_blocks_between(state, processed_height, height)

      _ ->
        # No height yet, so nothing to recover.
        Blocks.new(:BCH, height)
        state
    end
  end

  defp recover_blocks_between(state, processed_height, target_height) do
    Logger.debug("#{:BCH} recover blocks between #{processed_height} #{target_height}")

    active = Addresses.all_active_ids(:BCH)

    if Enum.empty?(active) do
      # No addresses so nothing to recover.
      Blocks.new(:BCH, target_height)
      set_ready()
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

      set_recovering({processed_height, target_height})

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
      set_recovering({current_height, target_height})

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
      Process.send_after(self(), :send_blockchain_info, state.sync_check_interval)

      set_syncing(progress)
    else
      if !state[:recover_target] do
        sync_done()
      end
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
          [{address, Money.new(amount, :BCH)}]
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
        [{address, Money.new(amount, :BCH)}]
      else
        _ -> []
      end
    end)
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
    Logger.debug("Subscribed to new #{:BCH} wallet: " <> inspect(addr))
    Protocol.send_address_subscribe(conn, hash)
  end

  defp enqueue_ping(state) do
    timeout = Map.get(state, :ping_timeout, :timer.minutes(1))
    :timer.send_after(timeout, self(), :send_ping)
  end

  defp create_info(state) do
    Map.get(state, :blockchain_info, %{})
    |> Map.put(:version, state[:version])
  end

  defp broadcast_info(state) do
    BackendEvents.broadcast({{:backend, :info}, %{info: create_info(state), currency_id: :BCH}})
    state
  end

  # Receive messages. Executed in another process, so it is OK to block here.
  def receive_messages(c) do
    case Protocol.recv(c) do
      {:ok, msg} ->
        GenServer.cast(__MODULE__, {:message, msg})
        receive_messages(c)

      {:error, {:unknown_msg, unknown}} ->
        Logger.warn("Unknown message received from Flowee: #{inspect(unknown)}")
        receive_messages(c)

      {:error, error} ->
        GenServer.call(__MODULE__, {:connection_error, error})
    end
  end
end
