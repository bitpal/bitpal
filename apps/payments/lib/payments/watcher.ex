defmodule Payments.Watcher do
  use GenServer

  # Client API

  def start_link(listener, request) do
    GenServer.start_link(__MODULE__, %{listener: listener, request: request})
  end

  # Server API

  @impl true
  def init(state) do
    IO.puts("initializing watcher")
    IO.inspect(state)

    # Simulate a seen tx after 2s
    :timer.send_after(2000, self(), :tx_seen)

    {:ok, state}
  end

  @impl true
  def handle_info(:tx_seen, state) do
    IO.puts("tx seen!")
    # IO.inspect(state)

    # Simulate a confirmation
    :timer.send_after(1000, self(), :new_block)

    send(state.listener, :tx_seen)
    {:noreply, state}
  end

  @impl true
  def handle_info(:new_block, state) do
    IO.puts("block seen!")
    # IO.inspect(state)

    # Simulate more confirmations
    :timer.send_after(1000, self(), :new_block)

    send(state.listener, :new_block)
    {:noreply, state}
  end

  @impl true
  def handle_info(info, state) do
    IO.puts("unhandled info")
    IO.inspect(info)
    IO.inspect(state)

    {:noreply, state}
  end

  @impl true
  def terminate(reason, state) do
    IO.inspect("terminate/2 callback")
    IO.inspect({:reason, reason})
    IO.inspect({:state, state})
  end
end

