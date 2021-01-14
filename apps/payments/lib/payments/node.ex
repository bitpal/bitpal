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
  def handle_cast({:message, msg}, state) do
    # We got a message from Flowee, inspect it and act upon it!
    case msg do
      %Message{type: :newBlock, data: _} ->
        IO.puts("New block!")

      %Message{type: :version, data: %{version: ver}} ->
        IO.puts("Running version: " <> ver)

      _ ->
        IO.puts("Unknown message!")
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

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    if pid == state[:listenPid] do
      # The Flowee process died. Close our connection and restart it!
      Connection.close(state[:connection])
      {:noreply, start_flowee(state)}
    else
      # Something else happened.
      {:noreply, state}
    end
  end

  # (re)start our connection to Flowee
  def start_flowee(state) do
    # Connect to Flowee, and start listening for messages from it.
    c = Connection.connect()
    Map.put(state, :connection, c)

    # Start receiving messages for it.
    # Sorry I'm not using the "standard" monitoring... This solution has the benefit of being able
    # to restore subscriptions from "state" as needed.
    pid = spawn(fn -> receive_messages(c) end)
    Map.put(state, :listenPid, pid)

    # Monitor it for crashes.
    Process.monitor(pid)

    # Start subscribing to new block messages
    Protocol.send_block_subscribe(c)

    # Send a version message, just to test.
    Protocol.send_version(c)

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
