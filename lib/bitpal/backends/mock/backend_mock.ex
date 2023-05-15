defmodule BitPal.BackendMock do
  @behaviour BitPal.Backend
  use BitPalFactory
  use GenServer
  import BitPalSettings.ConfigHelpers
  alias BitPal.Backend
  alias BitPal.BackendManager
  alias BitPal.BackendStatusSupervisor
  alias BitPal.BlockchainEvents
  alias BitPal.Blocks
  alias BitPal.Cache
  alias BitPal.ProcessRegistry
  alias BitPal.Transactions
  alias BitPalSchemas.Currency
  alias BitPalSchemas.Invoice
  alias BitPalSchemas.TxOutput
  alias Ecto.Adapters.SQL.Sandbox

  @log_level Application.compile_env(:bitpal, [__MODULE__, :log_level], :error)

  @type backend :: pid()

  @impl Backend
  def assign_address(backend, invoice) do
    GenServer.call(backend, {:assign_address, invoice})
  end

  @impl Backend
  def watch_invoice(backend, address) do
    GenServer.call(backend, {:watch_invoice, address})
  end

  @impl Backend
  def supported_currency(pid) when is_pid(pid) do
    # Avoid GenServer calls, which is relevant if the backend is shut down instantly.
    # Only relevant for backends that have dynamically different currencies.
    {:ok, Cache.fetch!(BitPal.RuntimeStorage, pid)}
  end

  def supported_currency(backend) do
    GenServer.call(backend, :supported_currency)
  end

  @impl Backend
  def configure(backend, opts) do
    GenServer.call(backend, {:configure, opts})
  end

  @impl Backend
  def info(backend) do
    GenServer.call(backend, :info)
  end

  @impl Backend
  def refresh_info(_backend), do: :ok

  def stop_with_error(backend, error) do
    GenServer.cast(backend, {:stop_with_error, error})
  end

  def crash(backend) do
    GenServer.cast(backend, :crash)
  end

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def child_spec(opts) do
    if parent = opts[:parent] do
      Sandbox.allow(BitPal.Repo, parent, self())
    end

    opts =
      opts
      |> Keyword.put_new_lazy(:currency_id, &unique_currency_id/0)

    currency_id = Keyword.fetch!(opts, :currency_id)

    %{
      id: currency_id,
      start: {__MODULE__, :start_link, [opts]},
      restart: :transient
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
    server(invoice.payment_currency_id)
  end

  defp server(currency_id) when is_atom(currency_id) do
    {:ok, pid} = ProcessRegistry.get_process(via_tuple(currency_id))
    pid
  end

  # Server API

  @impl true
  def init(opts) do
    currency_id = Keyword.fetch!(opts, :currency_id)

    Registry.register(
      ProcessRegistry,
      Backend.via_tuple(currency_id),
      __MODULE__
    )

    Logger.put_process_level(self(), @log_level)

    Cache.put(BitPal.RuntimeStorage, self(), currency_id)

    {:ok, opts, {:continue, :init}}
  end

  @impl true
  def handle_continue(:init, opts) do
    if parent = opts[:parent] do
      Sandbox.allow(BitPal.Repo, parent, self())
    end

    currency_id = Keyword.fetch!(opts, :currency_id)
    BackendStatusSupervisor.set_starting(currency_id)

    cond do
      # Add a small timeout when dying, to avoid a small possibility of getting a monitored
      # {:error, :noproc} DOWN message instead of the message we expect in the test.
      opts[:shutdown_init] ->
        Process.sleep(10)
        {:stop, {:shutdown, :shutdown_init}, opts}

      opts[:fail_init] ->
        Process.sleep(10)
        {:stop, {:error, :fail_init}, opts}

      true ->
        {:noreply, opts, {:continue, :start}}
    end
  end

  @impl true
  def handle_continue(:start, opts) do
    currency_id = Keyword.fetch!(opts, :currency_id)

    state =
      Enum.into(opts, %{
        height: block_height(currency_id),
        auto: false,
        tx_index: 0
      })

    BlockchainEvents.subscribe(currency_id)

    if state.auto do
      setup_auto_blocks(state)
    end

    if sync_time = opts[:sync_time] do
      Process.send_after(self(), :sync_complete, sync_time)
      BackendStatusSupervisor.set_syncing(currency_id, 0.5)
    else
      BackendStatusSupervisor.set_status(currency_id, opts[:status] || :ready)
    end

    {:noreply, state}
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
    {:reply, {:ok, state.currency_id}, state}
  end

  @impl true
  def handle_call(:info, _, state) do
    {:reply, %{}, state}
  end

  @impl true
  def handle_call({:assign_address, invoice}, _from, state) do
    invoice = with_address(invoice, state)
    {:reply, {:ok, invoice}, state}
  end

  @impl true
  def handle_call({:watch_invoice, invoice}, _from, state) do
    if state.auto do
      setup_auto_invoice(invoice, state)
    end

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:tx_seen, invoice}, _from, state) do
    txid = unique_txid()

    {:ok, _} =
      Transactions.update(txid, outputs: [{invoice.address_id, invoice.expected_payment}])

    {:reply, txid, state}
  end

  @impl true
  def handle_call({:doublespend, invoice}, _from, state) do
    {:ok, tx} =
      case Transactions.to_address(invoice.address_id) do
        [] ->
          Transactions.update(unique_txid(),
            outputs: [{invoice.address_id, invoice.expected_payment}]
          )

        [tx | _rest] ->
          Transactions.update(tx.id, double_spent: true)
      end

    {:reply, tx.id, state}
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
  def handle_cast({:stop_with_error, error}, state) do
    {:stop, {:error, error}, state}
  end

  @impl true
  def handle_cast(:crash, _state) do
    raise("BOOM!")
  end

  @impl true
  def handle_info(:stop, state) do
    {:stop, :shutdown, state}
  end

  @impl true
  def handle_info({{:block, _}, %{height: height}}, state) do
    # Allows us to set block height in tests after initiolizing backend.
    {:noreply, %{state | height: height}}
  end

  @impl true
  def handle_info({:auto_tx_seen, invoice}, state) do
    {:ok, _} =
      Transactions.update(unique_txid(), outputs: [{invoice.address_id, invoice.expected_payment}])

    {:noreply, append_auto_confirm(state, invoice)}
  end

  @impl true
  def handle_info({:issue_blocks, block_count, time_between_blocks}, state) do
    if BackendManager.is_ready(state.currency_id) do
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

    BackendStatusSupervisor.set_ready(state.currency_id)

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
    existing = Transactions.to_address(invoice.address_id)

    if Enum.empty?(existing) do
      Transactions.update(unique_txid(),
        height: state.height,
        outputs: [{invoice.address_id, invoice.expected_payment}]
      )
    else
      for tx <- existing do
        {:ok, _} = Transactions.update(tx.id, height: state.height)
      end
    end

    state
  end
end
