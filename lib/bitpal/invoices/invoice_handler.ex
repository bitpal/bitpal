defmodule BitPal.InvoiceHandler do
  use GenServer
  alias BitPal.AddressEvents
  alias BitPal.BackendManager
  alias BitPal.BlockchainEvents
  alias BitPal.InvoiceEvents
  alias BitPal.Invoices
  alias BitPal.ProcessRegistry
  alias BitPal.Transactions
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

  @spec get_invoice(handler) :: Invoice.t()
  def get_invoice(handler) do
    GenServer.call(handler, :get_invoice)
  end

  # Server API

  @impl true
  def init(opts) do
    invoice_id = Keyword.fetch!(opts, :invoice_id)
    double_spend_timeout = Keyword.fetch!(opts, :double_spend_timeout)

    Registry.register(ProcessRegistry, via_tuple(invoice_id), invoice_id)

    # Callback to initializer routine to not block start_link
    send(self(), :init)

    {:ok, %{double_spend_timeout: double_spend_timeout, invoice_id: invoice_id}}
  end

  @impl true
  def handle_info(:init, state = %{invoice_id: invoice_id}) do
    Logger.debug("init handler: #{invoice_id}")

    # Locate a new invoice for self-healing purpises.
    # If we're restarted we need to get the up-to-date invoice.
    # After finalization invoice details must not change, and invoice states etc
    # should only be updated from this handler, so we can keep holding it.
    invoice = Invoices.fetch!(invoice_id)

    case invoice.status do
      :draft ->
        finalize(invoice, state)

      status ->
        # NOTE this means handler has crashed and we need to recover data
        Logger.warn("unknown status in handler: '#{status}'")
    end
  end

  @impl true
  def handle_info({:tx_seen, tx}, state) do
    invoice = Invoices.update_amount_paid(state.invoice)
    state = process_tx(state, tx)

    case Invoices.target_amount_reached?(invoice) do
      :underpaid ->
        {:noreply, %{state | invoice: invoice}}

      _ ->
        if invoice.required_confirmations == 0 do
          Process.send_after(self(), {:double_spend_timeout, tx.id}, state.double_spend_timeout)
        end

        process(invoice, state)
    end
  end

  @impl true
  def handle_info({:tx_confirmed, tx}, state) do
    invoice = Invoices.update_amount_paid(state.invoice)

    state =
      if Transactions.num_confirmations!(tx) >= invoice.required_confirmations do
        tx_processed(state, tx.id)
      else
        process_tx(state, tx)
      end

    case Invoices.target_amount_reached?(invoice) do
      :underpaid ->
        {:noreply, %{state | invoice: invoice}}

      _ ->
        {_, state} = process(invoice, state)
        try_into_paid(state)
    end
  end

  @impl true
  def handle_info({:double_spend_timeout, tx_id}, state) do
    state
    |> tx_processed(tx_id)
    |> try_into_paid()
  end

  @impl true
  def handle_info({:tx_double_spent, _tx}, state) do
    {:ok, invoice} = Invoices.double_spent(state.invoice)
    InvoiceEvents.broadcast_status(invoice)
    {:noreply, %{state | invoice: invoice}}
  end

  @impl true
  def handle_info({:tx_reversed, _tx}, _state) do
    # Need to handle reversals
  end

  @impl true
  def handle_info({:new_block, _currency, height}, state) do
    case Map.fetch(state, :processing_txs) do
      {:ok, txs} when map_size(txs) > 0 ->
        if state.invoice.required_confirmations > 0 do
          to_process =
            Enum.filter(txs, fn
              {_tx_id, nil} ->
                true

              {_tx_id, confirmed_height} ->
                height - confirmed_height + 1 < state.invoice.required_confirmations
            end)
            |> Enum.into(%{})

          state
          |> Map.put(:processing_txs, to_process)
          |> try_into_paid()
        else
          {:noreply, state}
        end

      _ ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(info, state) do
    Logger.warn("unhandled info/state in InvoiceHandler #{inspect(info)} #{inspect(state)}")
    {:noreply, state}
  end

  @impl true
  def handle_call(:get_invoice, _from, state) do
    {:reply, state.invoice, state}
  end

  defp finalize(invoice, state) do
    {:ok, invoice} = BackendManager.register(invoice)

    :ok = AddressEvents.subscribe(invoice.address_id)
    :ok = BlockchainEvents.subscribe(invoice.currency_id)

    {:ok, invoice} = Invoices.finalize(invoice)

    InvoiceEvents.broadcast_status(invoice)

    state =
      state
      |> Map.delete(:invoice_id)
      |> Map.put(:invoice, invoice)

    {:noreply, state}
  end

  defp process(invoice, state) do
    # It's fine if this fails?
    case Invoices.process(invoice) do
      {:ok, invoice} ->
        InvoiceEvents.broadcast_status(invoice)
        {:noreply, Map.put(state, :invoice, invoice)}

      {:error, _} ->
        {:noreply, Map.put(state, :invoice, invoice)}
    end
  end

  defp process_tx(state, tx) do
    Map.update(state, :processing_txs, %{tx.id => tx.confirmed_height}, fn waiting ->
      Map.put(waiting, tx.id, tx.confirmed_height)
    end)
  end

  defp tx_processed(state = %{processing_txs: txs}, tx_id) do
    Map.put(
      state,
      :processing_txs,
      Map.delete(txs, tx_id)
    )
  end

  defp tx_processed(state, _tx_id), do: state

  defp try_into_paid(state) do
    done? =
      Enum.empty?(Map.get(state, :processing_txs, %{})) &&
        Invoices.target_amount_reached?(state.invoice) != :underpaid

    if done? do
      state = Map.put(state, :invoice, Invoices.pay!(state.invoice))
      InvoiceEvents.broadcast_status(state.invoice)
      {:stop, :normal, state}
    else
      {:noreply, state}
    end
  end

  @spec via_tuple(Invoice.id()) :: {:via, Registry, any}
  def via_tuple(invoice_id) do
    ProcessRegistry.via_tuple({__MODULE__, invoice_id})
  end
end
