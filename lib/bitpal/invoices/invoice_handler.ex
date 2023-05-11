defmodule BitPal.InvoiceHandler do
  use GenServer
  alias BitPal.AddressEvents
  alias BitPal.BackendManager
  alias BitPal.BlockchainEvents
  alias BitPal.Blocks
  alias BitPal.Invoices
  alias BitPal.ProcessRegistry
  alias BitPal.Transactions
  alias BitPalSchemas.Invoice
  alias BitPalSchemas.TxOutput
  alias Ecto.Adapters.SQL.Sandbox
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

  @spec fetch_invoice!(handler) :: Invoice.t()
  def fetch_invoice!(handler) do
    GenServer.call(handler, :get_invoice)
  end

  @spec fetch_invoice(handler) :: {:ok, Invoice.t()} | {:error, :not_started}
  def fetch_invoice(handler) do
    try do
      {:ok, GenServer.call(handler, :get_invoice)}
    catch
      # The GenServer shuts down when an invoice has been paid, which causes
      # the caller to exit.
      :exit, _reason ->
        {:error, :not_started}
    end
  end

  # Server API

  @impl true
  def init(opts) do
    # Register process directly, to prevent race condition with manager calling the handler
    # directly after start_link.
    invoice_id = Keyword.fetch!(opts, :invoice_id)

    Registry.register(ProcessRegistry, via_tuple(invoice_id), invoice_id)

    {:ok, %{invoice_id: invoice_id, opts: opts}, {:continue, :init}}
  end

  @impl true
  def handle_continue(:init, %{invoice_id: invoice_id, opts: opts}) do
    Logger.debug("init handler: #{invoice_id}")

    if parent = opts[:parent] do
      Sandbox.allow(BitPal.Repo, parent, self())
    end

    # Locate a new invoice for self-healing purpises.
    # If we're restarted we need to get the up-to-date invoice.
    # After finalization invoice details must not change, and invoice states etc
    # should only be updated from this handler, so we can keep holding it.
    invoice = Invoices.fetch!(invoice_id)

    state =
      Keyword.take(opts, [:double_spend_timeout])
      |> Enum.into(%{block_height: 0, invoice_id: invoice_id})
      |> Map.put_new_lazy(:double_spend_timeout, fn -> Invoices.double_spend_timeout(invoice) end)
      |> Map.put(:invoice, invoice)

    case invoice.status do
      :draft ->
        {:noreply, state, {:continue, :finalize}}

      _ ->
        {:noreply, state, {:continue, :recover}}
    end
  end

  @impl true
  def handle_continue(:finalize, state = %{invoice: invoice}) do
    case BackendManager.register_invoice(invoice) do
      {:ok, invoice} ->
        subscribe(invoice)
        invoice = Invoices.finalize!(invoice)

        state =
          state
          |> Map.delete(:invoice_id)
          |> Map.put(:invoice, invoice)

        {:noreply, state}

      {:error, err} ->
        Logger.error("""
        Failed to register invoice with backend #{inspect(err)}
        Wanted currency: #{invoice.payment_currency_id}
        Supported currencies by the backends: #{inspect(BackendManager.currency_list())}
        """)

        {:stop, {:shutdown, err}}
    end
  end

  @impl true
  def handle_continue(:recover, state = %{invoice: invoice}) do
    subscribe(invoice)

    # Should always have a block since we're trying to recover
    block_height = Blocks.fetch_block_height!(invoice.payment_currency_id)
    invoice = Invoices.update_info_from_txs(invoice, block_height)

    txs =
      Enum.map(invoice.tx_outputs, fn tx ->
        if tx.confirmed_height == nil do
          send_double_spend_timeout(tx.txid, state)
        end

        {tx.txid, tx.confirmed_height}
      end)
      |> Enum.into(%{})

    state
    |> Map.put(:block_height, block_height)
    |> Map.delete(:invoice_id)
    |> Map.put(:invoice, invoice)
    |> ensure_invoice_is_processing(txs)
    |> clear_processed_txs(txs)
    |> try_into_paid()
  end

  @impl true
  def handle_info({{:tx, :seen}, %{id: txid}}, state) do
    block_height = state.block_height
    invoice = Invoices.update_info_from_txs(state.invoice, block_height)
    state = put_tx_to_process(state, txid, nil)

    # For 0-conf, clear txn after a short timeout from the processing waiting list,
    # regardless of if we've paid enough or not as that's a separate check.
    if invoice.required_confirmations == 0 do
      send_double_spend_timeout(txid, state)
    end

    case Invoices.target_amount_reached?(invoice) do
      :underpaid ->
        Invoices.broadcast_underpaid(invoice)
        {:noreply, %{state | invoice: invoice}}

      :overpaid ->
        Invoices.broadcast_overpaid(invoice)
        {:noreply, %{state | invoice: ensure_processing!(invoice)}}

      :ok ->
        {:noreply, %{state | invoice: ensure_processing!(invoice)}}
    end
  end

  @impl true
  def handle_info({{:tx, :confirmed}, %{id: txid, height: height}}, state) do
    block_height = state.block_height
    invoice = Invoices.update_info_from_txs(state.invoice, block_height)
    new_tx? = !processing_tx?(state, txid)

    state =
      if Transactions.calc_confirmations(height, block_height) >= invoice.required_confirmations do
        tx_processed(state, txid)
      else
        put_tx_to_process(state, txid, height)
      end

    # There's a race condition here where we may sometimes update the confirmed_height of a tx
    # before receiving the `new_block` message, but sometimes not. Therefore we need to broadcast
    # a processing message from either `tx_confirmed` or `new_block`.
    broadcast_processed_if_needed(state)

    case Invoices.target_amount_reached?(invoice) do
      :underpaid ->
        if new_tx?, do: Invoices.broadcast_underpaid(invoice)
        {:noreply, %{state | invoice: invoice}}

      :overpaid ->
        if new_tx?, do: Invoices.broadcast_overpaid(invoice)

        %{state | invoice: ensure_processing!(invoice)}
        |> try_into_paid()

      :ok ->
        %{state | invoice: ensure_processing!(invoice)}
        |> try_into_paid()
    end
  end

  @impl true
  def handle_info({:double_spend_timeout, txid}, state) do
    # FIXME need to check with backend first
    state
    |> tx_processed(txid)
    |> try_into_paid()
  end

  @impl true
  def handle_info({{:tx, :double_spent}, _txid}, state) do
    invoice = Invoices.double_spent!(state.invoice)
    {:noreply, %{state | invoice: invoice}}
  end

  @impl true
  def handle_info({{:tx, :reversed}, _tx}, state) do
    # NOTE Need to handle reversals
    {:noreply, state}
  end

  @impl true
  def handle_info({{:block, :new}, %{height: height}}, state = %{processing_txs: txs}) do
    state = Map.put(state, :block_height, height)

    if state.invoice.required_confirmations > 0 do
      state
      |> broadcast_processed_if_needed()
      |> clear_processed_txs(txs)
      |> try_into_paid()
    else
      {:noreply, state}
    end
  end

  def handle_info({{:block, :new}, %{height: height}}, state) do
    {:noreply, Map.put(state, :block_height, height)}
  end

  @impl true
  def handle_info({{:block, :set_height}, %{height: height}}, state = %{processing_txs: txs}) do
    state = Map.put(state, :block_height, height)

    if state.invoice.required_confirmations > 0 do
      state
      |> clear_processed_txs(txs)
      |> try_into_paid()
    else
      {:noreply, state}
    end
  end

  def handle_info({{:block, :set_height}, _params}, state) do
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

  defp subscribe(invoice) do
    :ok = AddressEvents.subscribe(invoice.address_id)
    :ok = BlockchainEvents.subscribe(invoice.payment_currency_id)
  end

  defp ensure_invoice_is_processing(state, txs) do
    if map_size(txs) > 0 && state.invoice.status == :open do
      %{state | invoice: ensure_processing!(state.invoice)}
    else
      state
    end
  end

  def ensure_processing!(invoice = %Invoice{status: {:processing, _}}), do: invoice
  def ensure_processing!(invoice), do: Invoices.process!(invoice)

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

  defp tx_processed(state, _txid), do: state

  defp processing_tx?(%{processing_txs: txs}, txid) do
    Map.has_key?(txs, txid)
  end

  defp processing_tx?(_state, _txid), do: false

  @spec clear_processed_txs(map, %{TxOutput.txid() => TxOutput.height()}) :: map
  defp clear_processed_txs(state, txs) when map_size(txs) > 0 do
    block_height = state.block_height
    required_confirmations = state.invoice.required_confirmations

    to_process =
      Enum.filter(txs, fn
        {_tx_id, nil} ->
          true

        {_tx_id, confirmed_height} ->
          block_height - confirmed_height + 1 < required_confirmations
      end)
      |> Enum.into(%{})

    Map.put(state, :processing_txs, to_process)
  end

  defp clear_processed_txs(state, _txs), do: state

  defp broadcast_processed_if_needed(state = %{invoice: %Invoice{status: {:processing, _}}}) do
    prev = state.invoice.confirmations_due
    invoice = Invoices.update_info_from_txs(state.invoice, state.block_height)

    # We only send a 0 confirmations due notice if it's confirmed in the same block the tx is discovered.
    # This handles a multiple confirmations case, so clients gets live updates when the required confs
    # decreases.
    if invoice.confirmations_due != prev && invoice.confirmations_due > 0 do
      Invoices.broadcast_processing(invoice)
    end

    Map.put(state, :invoice, invoice)
  end

  defp broadcast_processed_if_needed(state), do: state

  defp send_double_spend_timeout(txid, state) do
    Process.send_after(self(), {:double_spend_timeout, txid}, state.double_spend_timeout)
  end

  defp try_into_paid(state = %{invoice: invoice}) do
    done? =
      Enum.empty?(Map.get(state, :processing_txs, %{})) &&
        Invoices.target_amount_reached?(invoice) != :underpaid

    if done? do
      state = Map.put(state, :invoice, Invoices.pay!(invoice))

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
