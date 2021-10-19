defmodule BitPal.BackendMock do
  @behaviour BitPal.Backend

  use GenServer
  import BitPalSettings.ConfigHelpers
  alias BitPal.Addresses
  alias BitPal.Backend
  alias BitPal.BCH.Cashaddress
  alias BitPal.Blocks
  alias BitPal.Invoices
  alias BitPal.Transactions
  alias BitPalSchemas.Address
  alias BitPalSchemas.Invoice

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

  @impl Backend
  def ready?(_backend) do
    true
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

  def confirmed_in_new_block(backend \\ __MODULE__, invoice) do
    GenServer.call(backend, {:confirmed_in_new_block, invoice})
  end

  def issue_blocks(backend \\ __MODULE__, block_count, time_between_blocks \\ 0) do
    GenServer.call(backend, {:issue_blocks, block_count, time_between_blocks})
  end

  # Server API

  @impl true
  def init(opts) do
    opts =
      opts
      |> Enum.into(%{
        currency: :BCH,
        height: 0,
        auto: false,
        tx_index: 0
      })
      |> (fn map ->
            if Map.has_key?(map, :address) do
              map
            else
              Map.put_new(map, :xpub, Application.get_env(:bitpal, :xpub))
            end
          end).()

    if opts.auto do
      setup_auto_blocks(opts)
    end

    {:ok, opts}
  end

  @impl true
  def handle_call({:configure, opts}, _, state) do
    setup_auto = opts[:auto] && !state[:auto]

    state =
      update_state(state, opts, [:auto, :time_until_tx_seen, :time_between_blocks, :currency])

    if setup_auto do
      setup_auto_blocks(state)
    end

    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:supported_currencies, _, state) do
    {:reply, [state.currency], state}
  end

  @impl true
  def handle_call({:register, invoice}, _from, state) do
    {:ok, invoice} = ensure_address(invoice, state)

    if state.auto do
      setup_auto_invoice(invoice, state)
    end

    {:reply, invoice, state}
  end

  @impl true
  def handle_call({:tx_seen, invoice}, _from, state) do
    :ok = Transactions.seen(generate_txid(), [{invoice.address_id, invoice.amount}])
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:doublespend, invoice}, _from, state) do
    {:ok, tx} = Invoices.one_tx_output(invoice)
    :ok = Transactions.double_spent(tx.txid, [{invoice.address_id, tx.amount}])
    {:reply, :ok, state}
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
  def handle_info({:auto_tx_seen, invoice}, state) do
    :ok = Transactions.seen(generate_txid(), [{invoice.address_id, invoice.amount}])
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
    :ok = Blocks.new_block(state.currency, height)

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

  @spec ensure_address(Invoice.t(), map) :: {:ok, Address.t()}
  defp ensure_address(invoice, %{address: address_id}) do
    if address = Addresses.get(address_id) do
      {:ok, address}
    else
      Addresses.register_next_address(invoice.currency_id, address_id)
    end
  end

  defp ensure_address(invoice, %{xpub: xpub, currency: :BCH}) do
    Invoices.ensure_address(invoice, fn address_index ->
      Cashaddress.derive_address(xpub, address_index)
    end)
  end

  defp ensure_address(_invoice, %{xpub: _xpub, currency: currency}) do
    raise RuntimeError, "not implemented mocking with xpub for currency #{currency}"
  end

  defp generate_txid do
    "txid:#{Ecto.UUID.generate()}"
  end

  defp confirm_transactions(invoice, state) do
    txid =
      case Invoices.one_tx_output(invoice) do
        {:ok, tx} ->
          tx.txid

        _ ->
          generate_txid()
      end

    :ok = Transactions.confirmed(txid, [{invoice.address_id, invoice.amount}], state.height)

    state
  end
end
