defmodule BitPal.BackendMock do
  @behaviour BitPal.Backend

  use BitPalFactory
  use GenServer
  import BitPalSettings.ConfigHelpers
  alias BitPal.Backend
  alias BitPal.BackendEvents
  alias BitPal.BlockchainEvents
  alias BitPal.Blocks
  alias BitPal.Invoices
  alias BitPal.ProcessRegistry
  alias BitPal.Transactions
  alias BitPalSchemas.Currency
  alias BitPalSchemas.Invoice
  alias BitPalSchemas.TxOutput
  alias Ecto.Adapters.SQL.Sandbox

  @type backend :: pid()

  @impl Backend
  def register(backend, invoice) do
    GenServer.call(backend, {:register, invoice})
  end

  @impl Backend
  def supported_currency(backend) do
    GenServer.call(backend, :supported_currency)
  end

  @impl Backend
  def configure(backend, opts) do
    GenServer.call(backend, {:configure, opts})
  end

  @impl Backend
  def status(backend) do
    GenServer.call(backend, :status)
  end

  @impl Backend
  def info(backend) do
    GenServer.call(backend, :info)
  end

  @impl Backend
  def poll_info(_backend), do: :ok

  @impl Backend
  def start(backend) do
    GenServer.call(backend, :start)
  end

  @impl Backend
  def stop(backend) do
    GenServer.call(backend, :stop)
  end

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def child_spec(opts) do
    opts =
      opts
      |> Keyword.put_new_lazy(:currency_id, &unique_currency_id/0)

    currency_id = Keyword.fetch!(opts, :currency_id)

    %{
      id: currency_id,
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  @spec tx_seen(Invoice.t()) :: TxOutput.txid()
  def tx_seen(invoice) do
    GenServer.call(server(invoice), {:tx_seen, invoice})
  end

  @spec doublespend(Invoice.t()) :: TxOutput.txid()
  def doublespend(invoice) do
    GenServer.call(server(invoice), {:doublespend, invoice})
  end

  @spec confirmed_in_new_block(Invoice.t()) :: :ok
  def confirmed_in_new_block(invoice) do
    GenServer.call(server(invoice), {:confirmed_in_new_block, invoice})
  end

  @spec issue_blocks(Currency.id() | Invoice.t(), non_neg_integer, non_neg_integer) :: :ok
  def issue_blocks(ref, block_count, time_between_blocks \\ 0) do
    GenServer.call(server(ref), {:issue_blocks, block_count, time_between_blocks})
  end

  defp via_tuple(currency_id) do
    Backend.via_tuple(currency_id)
  end

  defp server(invoice = %Invoice{}) do
    server(invoice.currency_id)
  end

  defp server(currency_id) when is_atom(currency_id) do
    {:ok, pid} = ProcessRegistry.get_process(via_tuple(currency_id))
    pid
  end

  # Server API

  @impl true
  def init(opts) do
    if parent = opts[:parent] do
      Sandbox.allow(BitPal.Repo, parent, self())
    end

    currency_id = opts[:currency_id]

    state =
      Enum.into(opts, %{
        height: block_height(currency_id),
        auto: false,
        tx_index: 0,
        status: :ready
      })

    # Should send status event here too

    Registry.register(
      ProcessRegistry,
      Backend.via_tuple(currency_id),
      __MODULE__
    )

    BlockchainEvents.subscribe(currency_id)

    if state.auto do
      setup_auto_blocks(state)
    end

    send_status_event(state)

    {:ok, state}
  end

  @impl true
  def handle_call({:configure, opts}, _, state) do
    setup_auto = opts[:auto] && !state[:auto]

    state =
      update_state(state, opts, [:auto, :time_until_tx_seen, :time_between_blocks, :currency_id])

    if setup_auto do
      setup_auto_blocks(state)
    end

    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:supported_currency, _, state) do
    {:reply, state.currency_id, state}
  end

  @impl true
  def handle_call(:status, _, state) do
    {:reply, state.status, state}
  end

  @impl true
  def handle_call(:info, _, state) do
    {:reply, %{}, state}
  end

  @impl true
  def handle_call(:start, _, state) do
    sync_time = state[:sync_time]

    if sync_time do
      :timer.send_after(sync_time, :sync_complete)
      {:reply, :ok, change_status(state, {:syncing, 0.12})}
    else
      {:reply, :ok, sync_complete(state)}
    end
  end

  @impl true
  def handle_call(:stop, _, state) do
    {:reply, :ok, change_status(state, :stopped)}
  end

  @impl true
  def handle_call({:register, invoice}, _from, state) do
    invoice = with_address(invoice, state)

    if state.auto do
      setup_auto_invoice(invoice, state)
    end

    {:reply, {:ok, invoice}, state}
  end

  @impl true
  def handle_call({:tx_seen, invoice}, _from, state) do
    txid = unique_txid()
    :ok = Transactions.seen(txid, [{invoice.address_id, invoice.amount}])
    {:reply, txid, state}
  end

  @impl true
  def handle_call({:doublespend, invoice}, _from, state) do
    {:ok, tx} = Invoices.one_tx_output(invoice)
    :ok = Transactions.double_spent(tx.txid, [{invoice.address_id, tx.amount}])
    {:reply, tx.txid, state}
  end

  @impl true
  def handle_call({:confirmed_in_new_block, invoice}, _from, state) do
    state = incr_height(state)
    confirm_transactions(invoice, state)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:issue_blocks, block_count, time_between_blocks}, _from, state) do
    schedule_issue_blocks(block_count, time_between_blocks)
    {:reply, :ok, state}
  end

  @impl true
  def handle_info({{:block, _}, %{height: height}}, state) do
    # Allows us to set block height in tests after initiolizing backend.
    {:noreply, %{state | height: height}}
  end

  @impl true
  def handle_info({:auto_tx_seen, invoice}, state) do
    :ok = Transactions.seen(unique_txid(), [{invoice.address_id, invoice.amount}])
    {:noreply, append_auto_confirm(state, invoice)}
  end

  @impl true
  def handle_info({:issue_blocks, block_count, time_between_blocks}, state) do
    if is_started(state) do
      {:noreply, update_issue_blocks(block_count, time_between_blocks, state)}
    else
      schedule_issue_blocks(block_count, time_between_blocks)
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(:sync_complete, state) do
    {:noreply, sync_complete(state)}
  end

  defp sync_complete(state) do
    if state.auto do
      setup_auto_blocks(state)
    end

    change_status(state, :ready)
  end

  defp change_status(state, new_status) do
    %{state | status: new_status}
    |> send_status_event()
  end

  defp send_status_event(state = %{status: status, currency_id: currency_id}) do
    BackendEvents.broadcast({{:backend, :status}, %{status: status, currency_id: currency_id}})
    state
  end

  defp schedule_issue_blocks(block_count, time_between_blocks) do
    if block_count == :inf || block_count > 0 do
      :timer.send_after(time_between_blocks, {:issue_blocks, block_count, time_between_blocks})
    end
  end

  defp update_issue_blocks(block_count, time_between_blocks, state) do
    case block_count do
      :inf ->
        schedule_issue_blocks(:inf, time_between_blocks)
        incr_height(state)

      count when count >= 0 ->
        schedule_issue_blocks(block_count - 1, time_between_blocks)
        incr_height(state)

      true ->
        state
    end
  end

  defp incr_height(state) do
    height = state.height + 1
    :ok = Blocks.new_block(state.currency_id, height)

    %{state | height: height}
    |> auto_confirm_invoices
  end

  defp setup_auto_blocks(state) do
    schedule_issue_blocks(:inf, Map.get(state, :time_between_blocks, 5_000))
  end

  defp is_started(state) do
    state.status == :ready
  end

  defp setup_auto_invoice(invoice, state) do
    :timer.send_after(Map.get(state, :time_until_tx_seen, 1_000), {:auto_tx_seen, invoice})
  end

  defp auto_confirm_invoices(state = %{auto_confirm: invoices}) do
    state =
      Enum.reduce(invoices, state, fn invoice, state ->
        confirm_transactions(invoice, state)
      end)

    Map.delete(state, :auto_confirm)
  end

  defp auto_confirm_invoices(state) do
    state
  end

  defp append_auto_confirm(state, invoice) do
    Map.update(state, :auto_confirm, [invoice], fn xs -> [invoice | xs] end)
  end

  defp confirm_transactions(invoice, state) do
    txid =
      case Invoices.one_tx_output(invoice) do
        {:ok, tx} -> tx.txid
        _ -> unique_txid()
      end

    :ok = Transactions.confirmed(txid, [{invoice.address_id, invoice.amount}], state.height)

    state
  end
end
