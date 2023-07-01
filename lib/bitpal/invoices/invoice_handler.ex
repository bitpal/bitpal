defmodule BitPal.InvoiceHandler do
  use GenServer
  alias BitPal.AddressEvents
  alias BitPal.BackendManager
  alias BitPal.BlockchainEvents
  alias BitPal.Blocks
  alias BitPal.Invoices
  alias BitPal.ProcessRegistry
  alias BitPalSchemas.Invoice
  alias Ecto.Adapters.SQL.Sandbox
  require Logger

  # TODO
  # - :overpaid / :underpaid status_reasons
  # - Reload invoice from db
  # - Use postgres for notifications ??
  #   https://www.peterullrich.com/listen-to-database-changes-with-postgres-triggers-and-elixir

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
      restart: opts[:restart] || :transient
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
      Keyword.take(opts, [:double_spend_timeout, :manager])
      # - We store block_height to prevent race conditions where we might
      #   miss sending out a processing message.
      |> Enum.into(%{
        block_height: Blocks.get_height(invoice.payment_currency_id),
        invoice_id: invoice_id,
        double_spend_timeouts: MapSet.new(),
        txs_seen: MapSet.new()
      })
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
    case BackendManager.register_invoice(state.manager, invoice) do
      {:ok, invoice} ->
        subscribe(invoice)
        invoice = Invoices.finalize!(invoice)

        schedule_expiry(invoice)

        state =
          state
          |> Map.delete(:invoice_id)
          |> Map.put(:invoice, invoice)

        {:noreply, state}

      {:error, err} ->
        Logger.error("""
        Failed to register invoice with backend #{inspect(err)}
        Wanted currency: #{invoice.payment_currency_id}
        Supported currencies by the backends: #{inspect(BackendManager.currency_list(state.manager))}
        """)

        {:stop, :shutdown, state}
    end
  end

  @impl true
  def handle_continue(:recover, state = %{invoice: invoice}) do
    subscribe(invoice)
    schedule_expiry(invoice)

    # Should always have a block since we're trying to recover
    block_height = Blocks.fetch_height!(invoice.payment_currency_id)

    invoice =
      Invoices.update_info_from_txs(invoice, block_height)
      |> dbg()

    # FIXME what if transactions are already confirmed?
    txs =
      invoice.transactions
      |> Map.new(fn tx ->
        if invoice.required_confirmations == 0 && tx.height == 0 do
          IO.puts("sending double spend timeout #{inspect(tx)}")
          send_double_spend_timeout(tx.id, state)
        end

        {tx.id, tx.height}
      end)

    state
    |> Map.put(:block_height, block_height)
    |> Map.delete(:invoice_id)
    |> Map.put(:invoice, invoice)
    |> txs_seen(txs)
    |> update_invoice_state()
    |> issue_address_update()
    |> try_into_paid()
  end

  @impl true
  def handle_info({{:tx, :pending}, %{id: txid}}, state) do
    new_tx? = !MapSet.member?(state.txs_seen, txid)

    state =
      state
      |> tx_seen(txid)
      |> update_invoice_info()

    # For 0-conf, clear txn after a short timeout from the processing waiting list,
    # regardless of if we've paid enough or not as that's a separate check.
    if state.invoice.required_confirmations == 0 do
      send_double_spend_timeout(txid, state)
    end

    case Invoices.target_amount_reached?(state.invoice) do
      :underpaid ->
        if new_tx?, do: Invoices.broadcast_underpaid(state.invoice)
        {:noreply, state}

      :overpaid ->
        if new_tx?, do: Invoices.broadcast_overpaid(state.invoice)
        {:noreply, update_invoice_state(state)}

      :ok ->
        {:noreply, update_invoice_state(state)}
    end
  end

  @impl true
  def handle_info({{:tx, :confirmed}, %{id: txid}}, state) do
    new_tx? = !MapSet.member?(state.txs_seen, txid)

    # There's a race condition here where we may sometimes update the confirmed_height of a tx
    # before receiving the `new_block` message, but sometimes not. Therefore we need to broadcast
    # a processing message from either `tx_confirmed` or `new_block`.
    state =
      state
      |> tx_seen(txid)
      |> update_invoice_info()
      |> broadcast_processed_if_needed()

    case Invoices.target_amount_reached?(state.invoice) do
      :underpaid ->
        if new_tx?, do: Invoices.broadcast_underpaid(state.invoice)
        {:noreply, state}

      :overpaid ->
        if new_tx?, do: Invoices.broadcast_overpaid(state.invoice)

        state
        |> update_invoice_state()
        |> try_into_paid()

      :ok ->
        state
        |> update_invoice_state()
        |> try_into_paid()
    end
  end

  @impl true
  def handle_info({{:tx, :double_spent}, _tx}, state) do
    invoice = Invoices.double_spent!(state.invoice)
    {:noreply, %{state | invoice: invoice}}
  end

  @impl true
  def handle_info({{:tx, :reversed}, _tx}, state) do
    state =
      state
      |> update_invoice_info()
      |> broadcast_processed_if_needed()

    {:noreply, state}
  end

  @impl true
  def handle_info({{:tx, :failed}, _tx}, state) do
    invoice = Invoices.failed!(state.invoice)
    {:stop, :normal, %{state | invoice: invoice}}
  end

  @impl true
  def handle_info({:double_spend_timeout, txid}, state) do
    state
    |> with_double_spend_timeout(txid)
    |> issue_address_update()
    |> update_invoice_info()
    |> try_into_paid()
  end

  @impl true
  def handle_info(:expire, state) do
    if Invoices.can_expire?(state.invoice) do
      invoice = Invoices.expire!(state.invoice)
      {:stop, :normal, %{state | invoice: invoice}}
    else
      Logger.debug("Can't expire invoice #{inspect(state.invoice)}")
      {:noreply, state}
    end
  end

  @impl true
  def handle_info({{:block, :new}, %{height: height}}, state) do
    state
    |> Map.put(:block_height, height)
    |> update_invoice_info()
    |> broadcast_processed_if_needed()
    |> try_into_paid()
  end

  def handle_info(
        {{:block, :reorg}, %{new_height: new_height, split_height: split_height}},
        state
      ) do
    state = Map.put(state, :block_height, new_height)

    # Only broadcast invoice info if all transaction are unaffected by the reorg (# conf might change).
    # Otherwise wait for a {:tx, :confirmed} or {:tx, :reversed} message that the backend must send,
    # and the broadcast will be done there instead.
    # This is because we can't know if the transaction will still be confirmed here,
    # and the backend won't send out a message for transactions that are confirmed in previous blocks.
    #
    # split_height refers to the last untouched block, so we can update txs on that block and below.
    if state.invoice.required_confirmations > 0 &&
         Enum.any?(state.invoice.transactions) &&
         Invoices.all_txs_below_height?(state.invoice, split_height + 1) do
      state =
        state
        |> update_invoice_info()
        |> broadcast_processed_if_needed()

      {:noreply, state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(info, state) do
    Logger.error("unhandled info/state in InvoiceHandler #{inspect(info)} #{inspect(state)}")
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

  defp schedule_expiry(%Invoice{valid_until: nil}), do: nil

  defp schedule_expiry(%Invoice{valid_until: valid_until}) do
    now = DateTime.utc_now()
    diff = DateTime.diff(valid_until, now, :millisecond)

    if diff > 0 do
      Process.send_after(self(), :expire, diff)
    else
      send(self(), :expire)
    end
  end

  # defp ensure_invoice_state(invoice = %Invoice{}) do
  #   cond do
  #     has_txs? && target_reached? ->
  #       # ensure_processing!(state)
  #
  #     has_txs? && !target_reached? ->
  #       Invoices.underpaid!(invoice)
  #
  #     !has_txs? ->
  #       state
  #   end
  # end

  # NOTE if we use postgres notifications we can just subscribe there?
  # The only thing we can't subscribe to do calculate confirmations_due there, that's still needed here.
  # But can solved by subscribing to new block and then calculate previous message.
  # But how to handle :uncollectible -> :void without a handler?
  #  maybe do it all in a single GenServer?
  defp stop_if_done(state) do
    case InvoiceStatus.state(state.invoice) do
      :uncollectible | :paid | :void ->
        {:stop, :normal, state}

      _ ->
        {:noreply, state}
    end
  end

  defp update_invoice_state(state) do
    if Enum.any?(state.invoice.transactions) do
      state = ensure_processing!(state)

      case Invoices.target_amount_reached?(state.invoice) do
        :underpaid ->
          ensure_underpaid!(state)

        _ ->
          if accept_payment?(state.invoice, state.double_spend_timeouts) do
            Map.put(state, :invoice, Invoices.pay!(state.invoice))
          else
            state
          end
      end
    else
      state
    end
  end

  def ensure_processing!(state) do
    if state.invoice.status == :open do
      invoice = Invoices.process!(state.invoice)

      state
      |> Map.merge(%{
        invoice: invoice,
        prev_processing_broadcat: processing_broadcast_key(invoice)
      })
    else
      state
    end
  end

  def ensure_underpaid!(state) do
    if state.invoice.status == :open do
      Map.put(state, :invoice, Invoices.underpaid!(state.invoice))
    else
      state
    end
  end

  #
  # defp

  defp broadcast_processed_if_needed(
         state = %{invoice: invoice = %Invoice{status: {:processing, _}}}
       ) do
    prev_broadcast = state[:prev_processing_broadcat]
    curr_broadcast = processing_broadcast_key(invoice)

    if processing_broadcast_key(invoice) != prev_broadcast && invoice.confirmations_due > 0 do
      Invoices.broadcast_processing(invoice)
      Map.put(state, :prev_processing_broadcat, curr_broadcast)
    else
      state
    end
  end

  defp broadcast_processed_if_needed(state), do: state

  defp send_double_spend_timeout(txid, state) do
    Process.send_after(self(), {:double_spend_timeout, txid}, state.double_spend_timeout)
  end

  defp with_double_spend_timeout(state, txid) do
    Map.update!(state, :double_spend_timeouts, fn timeouts ->
      MapSet.put(timeouts, txid)
    end)
  end

  defp txs_seen(state, txs) do
    Map.update!(state, :txs_seen, fn seen ->
      MapSet.union(seen, MapSet.new(txs, fn {txid, _} -> txid end))
    end)
  end

  defp tx_seen(state, txid) do
    Map.update!(state, :txs_seen, fn seen -> MapSet.put(seen, txid) end)
  end

  defp update_invoice_info(state) do
    %{state | invoice: Invoices.update_info_from_txs(state.invoice, state.block_height)}
  end

  defp issue_address_update(state) do
    # FIXME doesn't always pass (if backend isn't ready?)
    :ok = BackendManager.update_address(state.invoice)
    state
  end

  defp try_into_paid(state) do
    # FIXME invoice shouldn't be in {:processing, :verifying} when it has been underpaid?
    if accept_payment?(state.invoice, state.double_spend_timeouts) do
      invoice = Invoices.pay!(state.invoice)
      {:stop, :normal, %{state | invoice: invoice}}
    else
      {:noreply, state}
    end
  end

  defp accept_payment?(invoice, double_spend_timeouts) do
    IO.puts("accept_payment? #{invoice.id} #{inspect(double_spend_timeouts)}")

    confs? = has_confirmations?(invoice) |> dbg()
    target_amount? = target_amount_reached?(invoice) |> dbg()
    valid_txs? = valid_txs?(invoice) |> dbg()
    timeouts? = has_double_spend_timeouts?(invoice, double_spend_timeouts) |> dbg()

    confs? &&
      target_amount? &&
      valid_txs? &&
      timeouts?
  end

  defp valid_txs?(invoice) do
    # For a tx to be valid it must not be `failed`,
    # and a 0-conf cannot be double spent (but a confirmed tx can be).
    Enum.all?(invoice.transactions, fn tx ->
      (tx.height != 0 || !tx.double_spent) && !tx.failed
    end)
  end

  defp has_confirmations?(invoice) do
    invoice.confirmations_due == 0
  end

  defp has_double_spend_timeouts?(%{required_confirmations: required}, _) when required > 0 do
    true
  end

  defp has_double_spend_timeouts?(invoice, timeouts) do
    required_timeouts =
      invoice.transactions
      |> Enum.filter(fn tx -> tx.height == 0 end)
      |> MapSet.new(fn tx -> tx.id end)

    MapSet.subset?(required_timeouts, timeouts)
  end

  defp target_amount_reached?(invoice) do
    Invoices.target_amount_reached?(invoice) != :underpaid
  end

  defp processing_broadcast_key(invoice) do
    tx_info =
      invoice.transactions
      |> Enum.sort_by(fn tx -> tx.id end)
      |> Enum.map(fn tx ->
        [tx.height, boolean_key(tx.failed), boolean_key(tx.double_spent)]
      end)
      |> List.flatten()

    [invoice.confirmations_due | tx_info]
    |> Enum.join(":")
  end

  defp boolean_key(true), do: "1"
  defp boolean_key(false), do: "0"

  @spec via_tuple(Invoice.id()) :: {:via, Registry, any}
  def via_tuple(invoice_id) do
    ProcessRegistry.via_tuple({__MODULE__, invoice_id})
  end
end
