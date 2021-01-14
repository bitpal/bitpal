defmodule Payments.Watcher do
  use GenServer
  require Logger

  # Client API

  def start_link(listener, request) do
    GenServer.start_link(__MODULE__, %{listener: listener, request: request})
  end

  # Server API

  @impl true
  def init(state) do
    Logger.info("watcher: initializing #{inspect(state)}")

    # Callback to initializer routine to not block start_link
    send(self(), :init)

    {:ok, Map.put(state, :state, :init)}
  end

  @impl true
  def handle_info(:init, state = %{state: :init}) do
    Logger.info("watcher: real init")

    # FIXME load/store this in db for persistance
    # FIXME get a blockchain connection
    # FIXME timeout payment request after 24h?

    # Simulate a seen tx after 2s
    :timer.send_after(2000, self(), :tx_seen)

    {:noreply, %{state | state: :wait_for_tx}}
  end

  @impl true
  def handle_info(:tx_seen, state) do
    Logger.info("watcher: tx seen!")

    # FIXME Superflous?
    # We'll get a state changed event regardless
    # send(state.listener, :tx_seen)

    if state.request.required_confirmations == 0 do
      # Simulate 0-conf verification after 2s
      :timer.send_after(2000, self(), :verified)

      change_state(state, :wait_for_verification)
    else
      # Simulate a confirmation
      :timer.send_after(1000, self(), :new_block)

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
      # Simulate more confirmations
      :timer.send_after(1000, self(), :new_block)

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
    Logger.warning("unhandled info/state in Watcher #{inspect(info)} #{inspect(state)}")
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
    if state.state != new_state do
      send(state.listener, {:state_changed, new_state})
      {:noreply, %{state | state: new_state}}
    else
      {:noreply, state}
    end
  end
end
