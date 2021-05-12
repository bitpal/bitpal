defmodule BitPal.InvoiceHandler do
  use GenServer
  alias BitPal.BackendEvent
  alias BitPal.BackendManager
  alias BitPal.InvoiceEvent
  alias BitPal.Invoices
  alias BitPal.ProcessRegistry
  alias BitPalSchemas.Invoice
  require Logger

  @type handler :: pid

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def child_spec(opts) do
    invoice_id = Keyword.fetch!(opts, :invoice_id)

    %{
      id: invoice_id,
      start: {BitPal.InvoiceHandler, :start_link, [opts]},
      restart: :transient
    }
  end

  @spec update_subscriber(handler) :: :ok
  def update_subscriber(handler) do
    GenServer.call(handler, {:update_subscriber, self()})
  end

  @spec get_invoice_id(handler) :: Invoice.id()
  def get_invoice_id(handler) do
    GenServer.call(handler, :get_invoice_id)
  end

  # Server API

  @impl true
  def init(opts) do
    invoice_id = Keyword.fetch!(opts, :invoice_id)
    double_spend_timeout = Keyword.fetch!(opts, :double_spend_timeout)

    Registry.register(ProcessRegistry, via_tuple(invoice_id), invoice_id)

    # Callback to initializer routine to not block start_link
    send(self(), :init)

    {:ok, %{state: :init, double_spend_timeout: double_spend_timeout, invoice_id: invoice_id}}
  end

  @impl true
  def handle_info(:init, state = %{state: :init, invoice_id: invoice_id}) do
    Logger.debug("init handler: #{invoice_id}")

    # Locate a new invoice for self-healing purpises.
    # If we're restarted we need to get the up-to-date invoice.
    # So this is inefficient in the regular case, maybe we could keep track of a
    # "have this invoice been handled before by a handler" state somewhere,
    # to detect if we're restarted?
    invoice = Invoices.fetch!(invoice_id)

    BackendEvent.subscribe(invoice)

    # if invoice.address_id do
    # If the invoice has been assigned an address, then it means we might have crashed
    # so we should query the backend for all transactions to this address and
    # update our state/confirmations, as it's possible we've missed something.
    # end

    {:ok, invoice} = BackendManager.register(invoice)

    change_state(
      Map.put(state, :required_confirmations, invoice.required_confirmations),
      :wait_for_tx,
      invoice
    )
  end

  @impl true
  def handle_info(:tx_seen, state) do
    Logger.debug("invoice: tx seen! #{state.invoice_id}")

    if state.required_confirmations == 0 do
      change_state(state, :wait_for_verification)
    else
      change_state(state, :wait_for_confirmations)
    end
  end

  @impl true
  def handle_info(:doublespend, state) do
    broadcast(state.invoice_id, {:state, {:denied, :doublespend}})
    {:stop, :normal, state}
  end

  @impl true
  def handle_info({:confirmations, confirmations}, state) do
    Logger.debug("invoice: new block! #{state.invoice_id}")

    state = Map.put(state, :confirmations, confirmations)

    broadcast(state.invoice_id, {:confirmations, state.confirmations})

    if state.confirmations >= state.required_confirmations do
      accepted(state)
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(:verified, state = %{state: :wait_for_verification}) do
    Logger.debug("invoice: verified! #{state.invoice_id}")

    if state.required_confirmations == 0 do
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
  def handle_call({:update_subscriber, pid}, _from, state) do
    send(pid, {:state, state.state})

    if confirmations = state[:confirmations] do
      send(pid, {:confirmations, confirmations})
    end

    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:get_invoice_id, _from, state) do
    {:reply, state.invoice_id, state}
  end

  defp accepted(state) do
    broadcast(state.invoice_id, {:state, :accepted})
    {:stop, :normal, state}
  end

  defp change_state(state, new_state) do
    change_state_msg(state, new_state, {:state, new_state})
  end

  defp change_state(state, new_state, invoice) do
    change_state_msg(state, new_state, {:state, new_state, invoice})
  end

  defp change_state_msg(state, new_state, msg) do
    if Map.get(state, :state) != new_state do
      broadcast(state.invoice_id, msg)

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

  @spec broadcast(Invoice.id(), term) :: :ok | {:error, term}
  defp broadcast(invoice_id, msg) do
    InvoiceEvent.broadcast(invoice_id, msg)
  end

  @spec via_tuple(Invoice.id()) :: {:via, Registry, any}
  def via_tuple(invoice_id) do
    ProcessRegistry.via_tuple({__MODULE__, invoice_id})
  end
end
