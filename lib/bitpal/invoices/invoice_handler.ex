defmodule BitPal.InvoiceHandler do
  use GenServer
  alias BitPal.AddressEvents
  alias BitPal.BackendManager
  alias BitPal.BlockchainEvents
  alias BitPal.Blocks
  alias BitPal.InvoiceEvents
  alias BitPal.Invoices
  alias BitPal.ProcessRegistry
  alias BitPal.Transactions
  alias BitPalSchemas.Invoice
  alias BitPalSchemas.TxOutput
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

      _ ->
        recover(invoice, state)
    end
  end

  @impl true
  def handle_info({:tx_seen, txid}, state) do
    invoice = Invoices.update_amount_paid(state.invoice)
    state = put_tx_to_process(state, txid, nil)

    case Invoices.target_amount_reached?(invoice) do
      :underpaid ->
        {:noreply, %{state | invoice: invoice}}

      _ ->
        if invoice.required_confirmations == 0 do
          send_double_spend_timeout(txid, state)
        end

        process(invoice, state)
    end
  end

  @impl true
  def handle_info({:tx_confirmed, txid, height}, state) do
    invoice = Invoices.update_amount_paid(state.invoice)

    state =
      if Transactions.num_confirmations!(height, invoice.currency_id) >=
           invoice.required_confirmations do
        tx_processed(state, txid)
      else
        put_tx_to_process(state, txid, height)
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
  def handle_info({:double_spend_timeout, txid}, state) do
    state
    |> tx_processed(txid)
    |> try_into_paid()
  end

  @impl true
  def handle_info({:tx_double_spent, _txid}, state) do
    {:ok, invoice} = Invoices.double_spent(state.invoice)
    InvoiceEvents.broadcast_status(invoice)
    {:noreply, %{state | invoice: invoice}}
  end

  @impl true
  def handle_info({:tx_reversed, _tx}, _state) do
    # Need to handle reversals
  end

  @impl true
  def handle_info({:new_block, _currency, height}, state = %{processing_txs: txs}) do
    if state.invoice.required_confirmations > 0 do
      state
      |> clear_processed_txs(txs, height)
      |> try_into_paid()
    else
      {:noreply, state}
    end
  end

  def handle_info({:new_block, _currency, _height}, state) do
    {:noreply, state}
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
    case BackendManager.register(invoice) do
      {:ok, invoice} ->
        :ok = AddressEvents.subscribe(invoice.address_id)
        :ok = BlockchainEvents.subscribe(invoice.currency_id)

        {:ok, invoice} = Invoices.finalize(invoice)

        InvoiceEvents.broadcast_status(invoice)

        state =
          state
          |> Map.delete(:invoice_id)
          |> Map.put(:invoice, invoice)

        {:noreply, state}

      {:error, err} ->
        {:stop, {:shutdown, err}}
    end
  end

  defp recover(invoice, state) do
    :ok = AddressEvents.subscribe(invoice.address_id)
    :ok = BlockchainEvents.subscribe(invoice.currency_id)

    # Should always have a block since we're trying to recover
    height = Blocks.fetch_block_height!(invoice.currency_id)

    invoice = Invoices.update_amount_paid(invoice)

    txs =
      Enum.map(invoice.tx_outputs, fn tx ->
        if tx.confirmed_height == nil do
          send_double_spend_timeout(tx.txid, state)
        end

        {tx.txid, tx.confirmed_height}
      end)
      |> Enum.into(%{})

    state
    |> Map.delete(:invoice_id)
    |> Map.put(:invoice, invoice)
    |> ensure_invoice_is_processing(txs)
    |> clear_processed_txs(txs, height)
    |> try_into_paid()
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

  defp ensure_invoice_is_processing(state, txs) do
    if map_size(txs) > 0 && state.invoice.status == :open do
      {_, state} = process(state.invoice, state)
      state
    else
      state
    end
  end

  defp put_tx_to_process(state, txid, confirmed_height) do
    Map.update(state, :processing_txs, %{txid => confirmed_height}, fn waiting ->
      Map.put(waiting, txid, confirmed_height)
    end)
  end

  defp tx_processed(state = %{processing_txs: txs}, txid) do
    Map.put(
      state,
      :processing_txs,
      Map.delete(txs, txid)
    )
  end

  defp tx_processed(state, _tx_id), do: state

  @spec clear_processed_txs(map, %{TxOutput.txid() => TxOutput.height()}, non_neg_integer) :: map
  defp clear_processed_txs(state, txs, curr_height) when map_size(txs) > 0 do
    required_confirmations = state.invoice.required_confirmations

    to_process =
      Enum.filter(txs, fn
        {_tx_id, nil} ->
          true

        {_tx_id, confirmed_height} ->
          curr_height - confirmed_height + 1 < required_confirmations
      end)
      |> Enum.into(%{})

    Map.put(state, :processing_txs, to_process)
  end

  defp clear_processed_txs(state, _txs, _curr_height), do: state

  defp send_double_spend_timeout(txid, state) do
    Process.send_after(self(), {:double_spend_timeout, txid}, state.double_spend_timeout)
  end

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
