defmodule Payments.Node do
  use GenServer
  alias Payments.Watcher
  alias Payments.Connection
  alias Payments.Protocol
  alias Payments.Protocol.Message
  require Logger

  # Client API

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def register(request, watcher) do
    GenServer.cast(__MODULE__, {:register, request, watcher})
  end

  # Note: pubkey is a 20 byte P2PKHAddress (ripe160 hash?)
  # Use "Address.decode_cash_url" to decode a bitcoincash:...
  def watch_wallet(pubkey) do
    GenServer.cast(__MODULE__, {:watch, Payments.Address.create_hashed_output_script(pubkey)})
  end

  # Sever API

  @impl true
  def init(state) do
    Logger.info("Starting Payments.Node")

    state = start_flowee(state)

    {:ok, state}
  end

  @impl true
  def handle_cast({:register, request, watcher}, state) do
    # Simulate behaviour
    :timer.send_after(2000, self(), {:tx_seen, watcher})

    # FIXME register watcher better and use the watcher
    # FIXME maybe use Phoenix PubSub for messages instead?
    # Maybe that's overkill? Or is it?
    # FIXME How to handle unregistering?
    {:noreply, Map.put(state, request.address, watcher)}
  end

  @impl true
  def handle_cast({:watch, wallet}, state) do
    state = Map.put(state, :watching_wallets, [wallet | Map.get(state, :watching_wallets, [])])

    # If the hub is up and running, tell it that we are interested in another wallet.
    case state do
      %{hub_connection: c} ->
        Protocol.send_address_subscribe(c, wallet)

      _ ->
        nil
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast({:message, msg}, state) do
    # We got a message from Flowee, inspect it and act upon it!
    case msg do
      %Message{type: :newBlock, data: _} ->
        IO.puts("New block!")

      %Message{type: :version, data: %{version: ver}} ->
        IO.puts("Running version: " <> ver)

      %Message{type: :subscribeReply} ->
        # We could read the number of new subscriptions if we want to.
        nil

      %Message{type: :onTransaction, data: data} ->
        # We got notified of a transaction!
        on_transaction(data)

      %Message{type: :pong} ->
        # Just ignore it
        nil

      _ ->
        IO.puts("Unknown message: " <> Kernel.inspect(msg))
    end

    {:noreply, state}
  end

  # FIXME Simulations for tests, callbacks should come from node instead

  @impl true
  def handle_info({:tx_seen, watcher}, state) do
    send(watcher, :tx_seen)

    request = Watcher.get_request(watcher)

    if request.required_confirmations == 0 do
      :timer.send_after(2000, watcher, :verified)
    else
      :timer.send_after(1000, self(), {:issue_blocks, request.required_confirmations, watcher})
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:issue_blocks, num, watcher}, state) do
    send(watcher, :new_block)

    if num > 0 do
      :timer.send_after(1000, self(), {:issue_blocks, num - 1, watcher})
    end

    {:noreply, state}
  end

  # END simulations for tests

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

  # Called when we received a new transaction.
  # Note: We get the "transaction visible" immediately when we subscribe, as long as it is not accepted into a block.
  defp on_transaction(data) do
    # Note: There is more data here that we can track.
    case data do
      %{address: _addr, height: _height, amount: amount} ->
        IO.puts("Transaction accepted into the blockchain: " <> inspect(amount))

      %{address: _addr, amount: amount} ->
        IO.puts("Transaction visible: " <> inspect(amount))
    end
  end

  # (re)start our connection to Flowee
  def start_flowee(state) do
    # Connect to Flowee: The Hub, and start listening for messages from it.
    state = start_hub(state)

    # TODO: We probably need a connection to the indexer as well. That might be nicer to work with
    # in a blocking fashion though. We can't subscribe to changes from that.

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
    wallets = Map.get(state, :watching_wallets, [])

    if wallets != [] do
      # Note: This function handles a list of items!
      Protocol.send_address_subscribe(c, wallets)
    end

    state
  end

  # Receive messages. Executed in another process, so it is OK to block here.
  defp receive_messages(c) do
    msg = Protocol.recv(c)
    GenServer.cast(__MODULE__, {:message, msg})

    # Keep on working!
    receive_messages(c)
  end
end
