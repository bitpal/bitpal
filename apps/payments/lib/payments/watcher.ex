defmodule Payments.Watcher do
  use GenServer
  require Logger

  # Client API

  def start_link(request) do
    GenServer.start_link(__MODULE__, %{listener: self(), request: request})
  end

  def get_request(watcher) do
    GenServer.call(watcher, :get_request)
  end

  # Server API

  @impl true
  def init(state) do
    # Callback to initializer routine to not block start_link
    send(self(), :init)

    {:ok, Map.put(state, :state, :init)}
  end

  @impl true
  def handle_call(:get_request, _, state) do
    {:reply, state.request, state}
  end

  @impl true
  def handle_info(:init, state = %{state: :init}) do
    Logger.info("watcher: real init #{inspect(state.request)}")

    # FIXME load/store this in db for persistance
    # FIXME get a blockchain connection
    # FIXME timeout payment request after 24h?

    Payments.Node.register(state.request, self())

    change_state(state, :wait_for_tx)
  end

  @impl true
  def handle_info(:tx_seen, state) do
    Logger.info("watcher: tx seen!")

    if state.request.required_confirmations == 0 do
      change_state(state, :wait_for_verification)
    else
      change_state(state, :wait_for_confirmations)
    end
  end

  @impl true
  def handle_info(:new_block, state) do
    Logger.info("watcher: block seen!")

    # FIXME need to see if the tx is inside the blockchain before we do below

    state = Map.update(state, :confirmations, 1, &(&1 + 1))

    send(state.listener, {:confirmation, state.confirmations})

    if state.confirmations >= state.request.required_confirmations do
      accepted(state)
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(:verified, state = %{state: :wait_for_verification}) do
    Logger.info("watcher: verified")

    if state.request.required_confirmations == 0 do
      accepted(state)
    else
      change_state(state, :wait_for_confirmations)
    end
  end

  @impl true
  def handle_info(info, state) do
    # Note: This is not available on the server.
    Logger.warn("unhandled info/state in Watcher #{inspect(info)} #{inspect(state)}")
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, _state) do
    Logger.info("terminating watcher")
  end

  defp accepted(state) do
    send(state.listener, {:state_changed, :accepted})
    {:stop, :normal, state}
  end

  defp change_state(state, new_state) do
    if Map.get(state, :state) != new_state do
      send(state.listener, {:state_changed, new_state})
      {:noreply, %{state | state: new_state}}
    else
      {:noreply, state}
    end
  end
end
