defmodule Payments.Node do
  use GenServer
  alias Payments.Watcher
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
end
