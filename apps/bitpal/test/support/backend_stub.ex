defmodule BitPal.BackendStub do
  use GenServer
  require Logger
  alias BitPal.Backend
  alias BitPal.BackendAddressTrackerStub
  alias BitPal.Transactions

  @behaviour Backend

  # Client API

  def start_link(opts) do
    name = Keyword.get(opts, :name) || __MODULE__
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl Backend
  def register(backend, invoice) do
    GenServer.call(backend, {:register, invoice})
  end

  @impl Backend
  def supported_currencies(backend) do
    GenServer.call(backend, :supported_currencies)
  end

  def child_spec(arg) do
    id = Keyword.get(arg, :name) || __MODULE__

    %{
      id: id,
      start: {BitPal.BackendStub, :start_link, [arg]}
    }
  end

  # Server API

  @impl true
  def init(opts) do
    opts =
      opts
      |> Enum.into(%{})
      |> Map.put_new(:currencies, [:bch])

    {:ok, opts}
  end

  @impl true
  def handle_call(:supported_currencies, _, state = %{currencies: currencies}) do
    {:reply, currencies, state}
  end

  @impl true
  def handle_call({:register, invoice}, _from, state) do
    invoice = Transactions.new(invoice)

    # Simulate tx states
    # FIXME should be inside a DynamicSupervisor?
    BackendAddressTrackerStub.start_link(invoice: invoice, backend: self())

    {:reply, invoice, state}
  end

  @impl true
  def handle_info({:message, msg, invoice}, state) do
    case msg do
      :tx_seen ->
        Transactions.seen(invoice.address, invoice.amount)

      {:new_block, confirmations} ->
        Transactions.accepted(invoice.address, invoice.amount, confirmations)

      _ ->
        Logger.warn("Unknown msg for backend stub! #{inspect(msg)}")
    end

    {:noreply, state}
  end
end
