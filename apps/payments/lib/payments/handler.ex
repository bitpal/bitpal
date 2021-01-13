defmodule Payments.Handler do
  use GenServer

  # Client API

  def start_link() do
    # FIXME can initialize with listener/requests?
    GenServer.start_link(__MODULE__, nil)
  end

  def subscribe(handler, listener, request) do
    # Simulate a seen tx after 2s
    :timer.send_after(2000, handler, :tx_seen)
    IO.puts("after 2s tx_seen")

    {:noreply, %{listener: listener, request: request}}
  end

  # Server API

  @impl true
  def init(_) do
    {:ok, %{}}
  end

  @impl true
  def handle_info(:tx_seen, state) do
    IO.puts("tx seen!")

    # Simulate a confirmation
    :timer.send_after(3000, self(), :new_block)

    send(state.listener, :tx_seen)
    {:noreply, state}
  end

  @impl true
  def handle_info(:new_block, state) do
    IO.puts("block seen!")

    # Simulate more confirmations
    :timer.send_after(1000, self(), :new_block)

    send(state.listener, :new_block)
    {:noreply, state}
  end
end

