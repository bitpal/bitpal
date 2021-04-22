defmodule BitPal.Backend.Flowee do
  use GenServer
  require Logger
  alias BitPal.Backend.Flowee.Connection
  alias BitPal.Backend.Flowee.Protocol
  alias BitPal.Backend.Flowee.Protocol.Message
  alias BitPal.Transactions
  alias BitPal.BCH.Cashaddress
  alias BitPal.Backend

  @behaviour Backend

  # Client API

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  # Returns the amount of satoshi to ask for. Note: This will be modified slightly so that the system
  # is able to differentiate between different transactions.
  @impl Backend
  def register(backend, invoice) do
    GenServer.call(backend, {:register, invoice})
  end

  @impl Backend
  def supported_currencies(_backend) do
    [:bch]
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
  def init(state) do
    Logger.info("Starting Flowee")

    state = start_flowee(state)

    {:ok, state}
  end

  @impl true
  def handle_call({:register, invoice}, _from, state) do
    # Make sure we are subscribed to the wallet.
    state = watch_wallet(invoice.address, state)

    # Register the wallet with the Transactions svc.
    satoshi = Transactions.new(invoice)

    # Good to go! Report back!
    {:reply, satoshi, state}
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

      %Message{type: :newBlock, data: data} ->
        on_new_block(data, state)

      %Message{type: :version, data: %{version: ver}} ->
        Logger.info("Running Flowee server version: " <> ver)

      %Message{type: :subscribeReply} ->
        # We could read the number of new subscriptions if we want to.
        nil

      %Message{type: :onTransaction, data: data} ->
        # We got notified of a transaction!
        on_transaction(data, state)

      %Message{type: :onDoubleSpend, data: data} ->
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
        :timer.send_after(:timer.minutes(1), self(), {:send_ping})

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
  defp on_info(data, _state) do
    %{blocks: height} = data
    old_height = Transactions.get_height()

    Logger.info(
      "Startup: new block height: " <> inspect(height) <> ", was: " <> inspect(old_height)
    )

    Transactions.set_height(height)

    # NOTE: Examine some old blocks!?
  end

  # Called when a new block has been mined (regardless of whether or not it contains one of our transactions)
  defp on_new_block(data, _state) do
    %{height: height} = data
    Logger.info("New block. Height is now: " <> inspect(height))
    Transactions.set_height(height)
  end

  # Called when we received a new transaction.
  # Note: We get the "transaction visible" immediately when we subscribe, as long as it is not accepted into a block.
  # Note: Does not get to modify the state!
  defp on_transaction(data, state) do
    hash_to_addr = Map.get(state, :watching_hashes, state)

    # Convert the transaction, it is a hash:
    %{address: hash} = data
    address = Map.get(hash_to_addr, hash.data, nil)

    if address != nil do
      # We know this address! Tell Transactions about our finding!
      case data do
        %{height: height, amount: amount} ->
          Transactions.accepted(address, amount, height)

        %{amount: amount} ->
          Transactions.seen(address, amount)
      end
    end
  end

  # Called when we received a double spend.
  defp on_double_spend(data, state) do
    hash_to_addr = Map.get(state, :watching_hashes, state)

    # Convert the transaction, it is a hash:
    %{address: hash, amount: amount} = data
    address = Map.get(hash_to_addr, hash.data, nil)

    if address != nil do
      # We know this address! Tell Transactions about our finding!
      Transactions.doublespend(address, amount)
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
      wallets = Map.put(wallets, wallet, hash)

      hashes = Map.get(state, :watching_hashes, %{})
      hashes = Map.put(hashes, hash, wallet)

      # If the connection is up and running, tell it about the new wallet now.
      case state do
        %{hub_connection: c} ->
          subscribe_addr(c, wallet, hash)

        _ ->
          nil
      end

      # Add the wallets back into the state.
      state = Map.put(state, :watching_wallets, wallets)
      state = Map.put(state, :watching_hashes, hashes)
      state
    end
  end

  # (re)start our connection to Flowee
  def start_flowee(state) do
    # Connect to Flowee: The Hub, and start listening for messages from it.
    state = start_hub(state)

    # We could start additional connections here.

    state
  end

  # Connection to The Hub.
  defp start_hub(state) do
    c = Connection.connect()
    state = Map.put(state, :hub_connection, c)

    # Start receiving messages for it.
    # Sorry I'm not using the "standard" monitoring... This solution has the benefit of being able
    # to restore subscriptions from "state" as needed.
    pid = spawn(fn -> receive_messages(c) end)
    state = Map.put(state, :hub_pid, pid)

    # Monitor it for crashes.
    Process.monitor(pid)

    # Start sending pings
    :timer.send_after(:timer.minutes(1), self(), {:send_ping})

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

  # Convert a "bitcoin:..." address to what is needed by Flowee.
  defp convert_addr(address) do
    key = Cashaddress.decode_cash_url(address)
    hash = Cashaddress.create_hashed_output_script(key)
    hash
  end

  # Helper to subscribe to an address. Accepts the output from "convert_addr".
  defp subscribe_addr(connection, addr, hash) do
    Logger.info("Subscribed to new wallet: " <> inspect(addr))
    Protocol.send_address_subscribe(connection, hash)
  end

  # Receive messages. Executed in another process, so it is OK to block here.
  defp receive_messages(c) do
    msg = Protocol.recv(c)
    GenServer.cast(__MODULE__, {:message, msg})

    # Keep on working!
    receive_messages(c)
  end
end
