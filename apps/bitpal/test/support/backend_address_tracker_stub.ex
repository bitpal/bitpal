defmodule BitPal.BackendAddressTrackerStub do
  use GenServer

  # Close after this amount of confirmations, to reduce spam
  @max_confirmations 10

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  # Server API

  @impl true
  def init(opts) do
    enqueue_state_change()

    opts =
      opts
      |> Enum.into(%{})
      |> Map.put_new(:state, :wait_for_tx)

    {:ok, opts}
  end

  @impl true
  def handle_info(:next_state, state = %{confirmations: confirmations})
      when confirmations > @max_confirmations do
    {:stop, :normal, state}
  end

  @impl true
  def handle_info(:next_state, state) do
    enqueue_state_change()
    {:noreply, next_state(state)}
  end

  defp enqueue_state_change() do
    send(self(), :next_state)
  end

  defp next_state(state = %{state: :wait_for_tx}) do
    broadcast(:tx_seen, state)
    %{state | state: :blocks}
  end

  defp next_state(state = %{state: :blocks}) do
    confirmations = Map.get(state, :confirmations, 0)
    broadcast({:new_block, confirmations}, state)

    # FIXME should be able to send doublespend or block reversal messages too
    state
    |> Map.put(:confirmations, confirmations + 1)
  end

  defp broadcast(msg, %{backend: backend, invoice: invoice}) do
    send(backend, {:message, msg, invoice})
  end
end
