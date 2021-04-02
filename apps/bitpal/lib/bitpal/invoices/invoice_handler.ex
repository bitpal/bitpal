defmodule BitPal.InvoiceHandler do
  use GenServer
  require Logger
  alias BitPal.Invoice
  alias BitPal.InvoiceEvent
  alias BitPal.BackendManager

  # How long to wait for double spending... (ms)
  # FIXME should be configurable
  @double_spend_timeout 2000

  # Client API

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  def child_spec(arg) do
    invoice = Keyword.fetch!(arg, :invoice)

    %{
      id: Invoice.id(invoice),
      start: {BitPal.InvoiceHandler, :start_link, [%{invoice: invoice}]},
      restart: :transient
    }
  end

  # Server API

  @impl true
  def init(state) do
    # Callback to initializer routine to not block start_link
    send(self(), :init)

    {:ok, Map.put(state, :state, :init)}
  end

  @impl true
  def handle_info(:init, state = %{state: :init, invoice: invoice}) do
    Logger.debug("init handler: #{inspect(invoice)}")

    {:ok, invoice} = BackendManager.track(invoice)

    change_state(%{state | invoice: invoice}, :wait_for_tx)
  end

  @impl true
  def handle_info(:tx_seen, state) do
    Logger.debug("invoice: tx seen!")

    if state.invoice.required_confirmations == 0 do
      change_state(state, :wait_for_verification)
    else
      change_state(state, :wait_for_confirmations)
    end
  end

  @impl true
  def handle_info(:doublespend_seen, state) do
    broadcast(state.invoice, {:state_changed, :denied})
    {:stop, :normal, state}
  end

  @impl true
  def handle_info({:new_block, confirmations}, state) do
    Logger.debug("invoice: new block!")

    # FIXME need to see if the tx is inside the blockchain before we do below
    state = Map.put(state, :confirmations, confirmations)

    broadcast(state.invoice, {:confirmation, state.confirmations})

    if state.confirmations >= state.invoice.required_confirmations do
      accepted(state)
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(:verified, state = %{state: :wait_for_verification}) do
    Logger.debug("invoice: verified!")

    if state.invoice.required_confirmations == 0 do
      accepted(state)
    else
      change_state(state, :wait_for_confirmations)
    end
  end

  @impl true
  def handle_info(info, state) do
    Logger.warn("unhandled info/state in InvoiceHandler #{inspect(info)} #{inspect(state)}")
    {:noreply, state}
  end

  defp accepted(state) do
    broadcast(state.invoice, {:state_changed, :accepted})
    {:stop, :normal, state}
  end

  defp change_state(state, new_state) do
    if Map.get(state, :state) != new_state do
      broadcast(state.invoice, {:state_changed, new_state})

      # # If now in "wait for verification", we wait a while more in case the transaction is double-spent.
      if new_state == :wait_for_verification do
        # Start the timer now.
        :timer.send_after(@double_spend_timeout, self(), :verified)
      end

      {:noreply, %{state | state: new_state}}
    else
      {:noreply, state}
    end
  end

  @spec broadcast(Invoice.t(), term) :: :ok | {:error, term}
  defp broadcast(invoice, msg) do
    InvoiceEvent.broadcast(invoice, msg)
  end
end
