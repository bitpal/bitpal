defmodule BitPal.Backend.Flowee do
  @behaviour BitPal.Backend
  use GenServer
  alias BitPal.Backend
  alias BitPal.Backend.Flowee.Connection
  alias BitPal.Backend.Flowee.Connection.Binary
  alias BitPal.Backend.Flowee.Protocol
  alias BitPal.Backend.Flowee.Protocol.Message
  alias BitPal.BCH.Cashaddress
  alias BitPal.Blocks
  alias BitPal.Invoices
  alias BitPal.Transactions
  require Logger

  @supervisor BitPal.Backend.Flowee.TaskSupervisor
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

  # Address is a "bitcoincash:..." address.
  # Note: This is mainly intended for testing. Registering requests will automagically start watching addresses.
  def watch_wallet(address) do
    GenServer.cast(__MODULE__, {:watch, address})
  end

  # Sever API

  @impl true
  def init(opts) do
    Logger.info("Starting Flowee")

    state =
      Enum.into(opts, %{})
      |> Map.put_new(:tcp_client, BitPal.TCPClient)

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

    state = watch_wallet(invoice.address_id, state)

    {:reply, invoice, state}
  end

  @impl true
  def handle_cast({:watch, wallet}, state) do
    {:noreply, watch_wallet(wallet, state)}
  end

  @impl true
  def handle_cast({:message, msg}, state) do
    # We got a message from Flowee, inspect it and act upon it!
    case msg do
      %Message{type: :info, data: data} ->
        on_info(data, state)

      %Message{type: :new_block, data: data} ->
        on_new_block(data, state)

      %Message{type: :version, data: %{version: ver}} ->
        Logger.info("Running Flowee server version: " <> ver)

      %Message{type: :subscribe_reply} ->
        # We could read the number of new subscriptions if we want to.
        nil

      %Message{type: :on_transaction, data: data} ->
        # We got notified of a transaction!
        on_transaction(data, state)

      %Message{type: :on_double_spend, data: data} ->
        # We got notified of a double spend...
        on_double_spend(data, state)

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
  def handle_info({:send_ping}, state) do
    case state do
      %{hub_connection: conn} ->
        # IO.puts("Sending ping")
        Protocol.send_ping(conn)
        enqueue_ping(state)

      _ ->
        # Connection not open. Nothing to do.
        nil
    end

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

  # Called when we received information from the blockchain.
  defp on_info(%{blocks: height}, _state) do
    Logger.info("Startup: new block height: #{inspect(height)}")
    Blocks.set_block_height(@bch, height)
  end

  # Called when a new block has been mined (regardless of whether or not it contains one of our transactions)
  defp on_new_block(%{height: height}, _state) do
    Logger.info("New block. Height is now: " <> inspect(height))
    Blocks.new_block(@bch, height)
  end

  # Called when we received a new transaction.
  # Note: We get the "transaction visible" immediately when we subscribe,
  # as long as it is not accepted into a block.
  # Note: Does not get to modify the state!
  defp on_transaction(data, state) do
    hash_to_addr = Map.get(state, :watching_hashes, state)

    # Check all outputs, there may be more than one output that is interesting to us, but also ones that we should ignore.
    data.outputs
    |> Enum.each(fn {address_hash, amount} ->
      # Convert the transaction, it is a hash:
      address = Map.get(hash_to_addr, address_hash.data, nil)

      if address != nil do
        # We know this address! Tell the world about our finding!
        case data do
          %{txid: txid, height: height} ->
            Transactions.confirmed(
              binary_to_string(txid),
              address,
              Money.new(amount, @bch),
              height
            )

          %{txid: txid} ->
            Transactions.seen(
              binary_to_string(txid),
              address,
              Money.new(amount, @bch)
            )
        end
      end
    end)
  end

  # Called when we received a double spend.
  defp on_double_spend(%{txid: txid, address: hash, amount: amount}, state) do
    hash_to_addr = Map.get(state, :watching_hashes, state)

    # Convert the transaction, it is a hash:
    address = Map.get(hash_to_addr, hash.data, nil)

    if address != nil do
      # We know this address! Tell the world about our finding!
      Transactions.double_spent(txid, address, Money.new(amount, @bch))
    end
  end

  # Start watching a wallet. "wallet" is a "bitcoincash:..." address.
  defp watch_wallet(wallet, state) do
    wallets = Map.get(state, :watching_wallets, %{})

    if Map.has_key?(wallets, wallet) do
      # Already there. We don't need to add it!
      state
    else
      # Add a mapping from the bitcoin: address and the hashed key and in reverse.
      hash = convert_addr(wallet)
      # wallets = Map.put(wallets, wallet, hash)

      hashes = Map.get(state, :watching_hashes, %{})
      hashes = Map.put(hashes, hash, wallet)

      # If the connection is up and running, tell it about the new wallet now.
      case state do
        %{hub_connection: c} ->
          subscribe_addr(c, wallet, hash)

        _ ->
          nil
      end

      # Add the wallets back into the state.  state = Map.put(state, :watching_wallets, wallets)
      Map.put(state, :watching_hashes, hashes)
    end
  end

  # (re)start our connection to Flowee
  def start_flowee(state) do
    Task.Supervisor.start_link(name: @supervisor)

    # Connect to Flowee: The Hub, and start listening for messages from it.
    state = start_hub(state)

    # We could start additional connections here.

    state
  end

  # Connection to The Hub.
  defp start_hub(state) do
    c = Connection.connect(state.tcp_client)
    state = Map.put(state, :hub_connection, c)

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

    # Start subscribing to new block messages
    Protocol.send_block_subscribe(c)

    # Subscribe to any wallets we were asked to.
    wallets = Map.get(state, :watching_wallets, %{})

    if wallets != %{} do
      Enum.each(wallets, fn {k, v} -> subscribe_addr(c, k, v) end)
    end

    # Query the current status of the blockchain. This is so that we can update the current height
    # of the blockchain and to look for confirmations for transactions we might have missed.
    Protocol.send_blockchain_info(c)

    state
  end

  defp enqueue_ping(state) do
    timeout = Map.get(state, :ping_timeout, :timer.minutes(1))
    :timer.send_after(timeout, self(), {:send_ping})
  end

  # Convert a "bitcoin:..." address to what is needed by Flowee.
  defp convert_addr(address) do
    address
    |> Cashaddress.decode_cash_url()
    |> Cashaddress.create_hashed_output_script()
  end

  defp binary_to_string(%Binary{data: data}) do
    Cashaddress.binary_to_hex(data)
  end

  # Helper to subscribe to an address. Accepts the output from "convert_addr".
  defp subscribe_addr(connection, addr, hash) do
    Logger.info("Subscribed to new wallet: " <> inspect(addr))
    Protocol.send_address_subscribe(connection, hash)
  end

  # Receive messages. Executed in another process, so it is OK to block here.
  def receive_messages(c) do
    msg = Protocol.recv(c)
    GenServer.cast(__MODULE__, {:message, msg})

    # Keep on working!
    receive_messages(c)
  end
end
