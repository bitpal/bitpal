defmodule BitPal.BackendMock do
  @behaviour BitPal.Backend

  use GenServer
  import BitPal.ConfigHelpers
  alias BitPal.Backend
  alias BitPal.Transactions
  require Logger

  @type backend :: pid() | module()

  @impl Backend
  def register(backend, invoice) do
    GenServer.call(backend, {:register, invoice})
  end

  @impl Backend
  def supported_currencies(backend) do
    GenServer.call(backend, :supported_currencies)
  end

  @impl Backend
  def configure(backend \\ __MODULE__, opts) do
    GenServer.call(backend, {:configure, opts})
  end

  # Client API

  def start_link(opts) do
    opts = Keyword.put_new(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end

  def child_spec(arg) do
    id = Keyword.get(arg, :name) || __MODULE__

    %{
      id: id,
      start: {__MODULE__, :start_link, [arg]}
    }
  end

  def tx_seen(backend \\ __MODULE__, invoice) do
    GenServer.call(backend, {:tx_seen, invoice})
  end

  def doublespend(backend \\ __MODULE__, invoice) do
    GenServer.call(backend, {:doublespend, invoice})
  end

  def new_block(backend \\ __MODULE__, invoices) do
    GenServer.call(backend, {:new_block, invoices})
  end

  def issue_blocks(backend \\ __MODULE__, block_count, time_between_blocks \\ 0) do
    GenServer.call(backend, {:issue_blocks, block_count, time_between_blocks})
  end

  # Server API

  @impl true
  def init(opts) do
    opts =
      opts
      |> Enum.into(%{})
      |> Map.put_new(:currencies, [:bch])
      |> Map.put_new(:height, 0)
      |> Map.put_new(:auto, false)

    if opts.auto do
      setup_auto_blocks(opts)
    end

    {:ok, opts}
  end

  @impl true
  def handle_call({:configure, opts}, _, state) do
    setup_auto = opts[:auto] && !state[:auto]

    state =
      update_state(state, opts, [:auto, :time_until_tx_seen, :time_between_blocks, :currencies])

    if setup_auto do
      setup_auto_blocks(state)
    end

    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:supported_currencies, _, state = %{currencies: currencies}) do
    {:reply, currencies, state}
  end

  @impl true
  def handle_call({:register, invoice}, _from, state) do
    invoice = Transactions.new(invoice)

    if state.auto do
      setup_auto_invoice(invoice, state)
    end

    {:reply, invoice, state}
  end

  @impl true
  def handle_call({:tx_seen, invoice}, _from, state) do
    Transactions.seen(invoice.address, invoice.amount)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:doublespend, invoice}, _from, state) do
    Transactions.doublespend(invoice.address, invoice.amount)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:new_block, invoices}, _from, state) when is_list(invoices) do
    state = incr_height(state)

    Enum.each(invoices, fn invoice ->
      Transactions.accepted(invoice.address, invoice.amount, state.height)
    end)

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:new_block, invoice}, _from, state) do
    state = incr_height(state)
    Transactions.accepted(invoice.address, invoice.amount, state.height)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:issue_blocks, block_count, time_between_blocks}, _from, state) do
    schedule_issue_blocks(block_count, time_between_blocks)
    {:reply, :ok, state}
  end

  @impl true
  def handle_info({:auto_tx_seen, invoice}, state) do
    Transactions.seen(invoice.address, invoice.amount)
    {:noreply, append_auto_confirm(state, invoice)}
  end

  @impl true
  def handle_info({:issue_blocks, block_count, time_between_blocks}, state) do
    state =
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

    {:noreply, state}
  end

  defp schedule_issue_blocks(block_count, time_between_blocks) do
    if block_count == :inf || block_count > 0 do
      :timer.send_after(time_between_blocks, {:issue_blocks, block_count, time_between_blocks})
    end
  end

  defp incr_height(state) do
    height = state.height + 1
    Transactions.set_height(height)

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
    Enum.each(invoices, fn invoice ->
      Transactions.accepted(invoice.address, invoice.amount, state.height)
    end)

    Map.delete(state, :auto_confirm)
  end

  defp auto_confirm_invoices(state) do
    state
  end

  defp append_auto_confirm(state, invoice) do
    Map.update(state, :auto_confirm, [invoice], fn xs -> [invoice | xs] end)
  end
end
