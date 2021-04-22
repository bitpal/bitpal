defmodule BitPal.InvoiceHandler do
  use GenServer
  require Logger
  alias BitPal.Invoice
  alias BitPal.InvoiceEvent
  alias BitPal.BackendManager

  @type handler :: pid

  # Client API

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  def child_spec(args) do
    opts = Enum.into(args, %{})

    %{
      id: Invoice.id(opts.invoice),
      start: {BitPal.InvoiceHandler, :start_link, [opts]},
      restart: :transient
    }
  end

  @spec get_invoice(handler) :: Invoice.t()
  def get_invoice(handler) do
    GenServer.call(handler, :get_invoice)
  end

  @spec subscribe_and_get_current(handler) :: :ok | {:error, term}
  def subscribe_and_get_current(handler) do
    invoice = get_invoice(handler)

    case InvoiceEvent.subscribe(invoice) do
      :ok -> update_subscriber(handler)
      err -> err
    end
  end

  @spec update_subscriber(handler) :: :ok
  def update_subscriber(handler) do
    GenServer.call(handler, {:update_subscriber, self()})
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
    Logger.debug("init handler: #{Invoice.id(invoice)}")

    {:ok, invoice} = BackendManager.track(invoice)

    change_state(%{state | invoice: invoice}, :wait_for_tx)
  end

  @impl true
  def handle_info(:tx_seen, state) do
    Logger.debug("invoice: tx seen! #{Invoice.id(state.invoice)}")

    if state.invoice.required_confirmations == 0 do
      change_state(state, :wait_for_verification)
    else
      change_state(state, :wait_for_confirmations)
    end
  end

  @impl true
  def handle_info(:doublespend, state) do
    broadcast(state.invoice, {:state, {:denied, :doublespend}, state.invoice})
    {:stop, :normal, state}
  end

  @impl true
  def handle_info({:confirmations, confirmations}, state) do
    Logger.debug("invoice: new block! #{Invoice.id(state.invoice)}")

    state = Map.put(state, :confirmations, confirmations)

    broadcast(state.invoice, {:confirmations, state.confirmations})

    if state.confirmations >= state.invoice.required_confirmations do
      accepted(state)
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(:verified, state = %{state: :wait_for_verification}) do
    Logger.debug("invoice: verified! #{Invoice.id(state.invoice)}")

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

  @impl true
  def handle_call(:get_invoice, _, state) do
    {:reply, state[:invoice], state}
  end

  @impl true
  def handle_call({:update_subscriber, pid}, _from, state) do
    send(pid, {:state, state.state})

    if confirmations = state[:confirmations] do
      send(pid, {:confirmations, confirmations})
    end

    {:reply, :ok, state}
  end

  defp accepted(state) do
    broadcast(state.invoice, {:state, :accepted, state.invoice})
    {:stop, :normal, state}
  end

  defp change_state(state, new_state) do
    if Map.get(state, :state) != new_state do
      broadcast(state.invoice, {:state, new_state})

      # # If now in "wait for verification", we wait a while more in case the transaction is double-spent.
      if new_state == :wait_for_verification do
        # Start the timer now.
        :timer.send_after(state.double_spend_timeout, self(), :verified)
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
