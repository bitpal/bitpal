defmodule HandlerSubscriberCollector do
  use GenServer
  alias BitPal.Addresses
  alias BitPal.ExchangeRate
  alias BitPal.InvoiceHandler
  alias BitPal.InvoiceManager
  alias BitPal.Invoices
  alias BitPal.InvoiceEvents
  alias BitPalSchemas.Invoice

  # Client API

  @spec create_invoice(keyword | map) :: {:ok, Invoice.t(), pid, pid}
  def create_invoice(params) when is_list(params) do
    create_invoice(Enum.into(params, %{}))
  end

  def create_invoice(params) do
    {:ok, stub} = start_link(nil)

    params =
      Map.merge(
        %{
          amount: Money.parse!(1.3, :BCH),
          exchange_rate: ExchangeRate.new!(Decimal.from_float(2.0), {:BCH, :USD}),
          required_confirmations: 0
        },
        params
      )

    {invoice, handler} = GenServer.call(stub, {:create_invoice, params})

    {:ok, invoice, stub, handler}
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def received(handler) do
    GenServer.call(handler, :received)
    |> Enum.reverse()
  end

  def await_status(handler, status) do
    Task.async(__MODULE__, :sleep_until_status, [handler, status])
    |> Task.await(1_000)

    {:ok, received(handler)}
  end

  def sleep_until_status(handler, status) do
    if contains_status?(handler, status) do
      :ok
    else
      Process.sleep(10)
      sleep_until_status(handler, status)
    end
  end

  def contains_status?(handler, status) do
    received(handler)
    |> Enum.any?(fn
      {:invoice_status, ^status, _} -> true
      _ -> false
    end)
  end

  def is_paid?(handler) do
    contains_status?(handler, :paid)
  end

  # Server API

  @impl true
  def init(_init_args) do
    {:ok, %{received: []}}
  end

  @impl true
  def handle_call({:create_invoice, params = %{address: {address, id}}}, _, state) do
    # Address specified, force the address.
    {:ok, invoice} = Invoices.register(Map.delete(params, :address))
    {:ok, addr} = Addresses.register(invoice.currency_id, address, id)
    Invoices.assign_address(invoice, addr)
    :ok = InvoiceEvents.subscribe(invoice)
    {:ok, invoice_id} = InvoiceManager.track(invoice)
    {:ok, handler} = InvoiceManager.get_handler(invoice_id)
    # Block until handler has finalized the invoice, which may change invoice details.
    invoice = InvoiceHandler.get_invoice(handler)
    if !Invoices.finalized?(invoice), do: raise("invoice not finalized yet!")

    {:reply, {invoice, handler}, state}
  end

  @impl true
  def handle_call({:create_invoice, params}, _, state) do
    {:ok, invoice} = Invoices.register(params)
    :ok = InvoiceEvents.subscribe(invoice)
    {:ok, invoice_id} = InvoiceManager.track(invoice)
    {:ok, handler} = InvoiceManager.get_handler(invoice_id)
    # Block until handler has finalized the invoice, which may change invoice details.
    invoice = InvoiceHandler.get_invoice(handler)
    if !Invoices.finalized?(invoice), do: raise("invoice not finalized yet!")

    {:reply, {invoice, handler}, state}
  end

  @impl true
  def handle_call(:received, _, state = %{received: received}) do
    {:reply, received, state}
  end

  @impl true
  def handle_info(info, state = %{received: received}) do
    {:noreply, %{state | received: [info | received]}}
  end
end
