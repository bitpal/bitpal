defmodule HandlerSubscriberCollector do
  use GenServer
  alias BitPal.Addresses
  alias BitPal.ExchangeRate
  alias BitPal.InvoiceEvents
  alias BitPal.InvoiceHandler
  alias BitPal.InvoiceManager
  alias BitPal.Invoices
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
          amount: 1.3,
          currency: :BCH,
          exchange_rate: 2.0,
          fiat_currency: :USD,
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

  def await_msg(handler, id) do
    Task.async(__MODULE__, :sleep_until_msg, [handler, id])
    |> Task.await(100)

    {:ok, received(handler)}
  end

  def sleep_until_msg(handler, id) do
    if contains_id?(handler, id) do
      :ok
    else
      Process.sleep(10)
      sleep_until_msg(handler, id)
    end
  end

  def contains_id?(handler, id) do
    received(handler)
    |> Enum.any?(fn
      {^id, _} -> true
      _ -> false
    end)
  end

  def is_paid?(handler) do
    contains_id?(handler, :invoide_paid)
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
    track(invoice, state)
  end

  @impl true
  def handle_call({:create_invoice, params}, _, state) do
    {:ok, invoice} = Invoices.register(params)
    track(invoice, state)
  end

  @impl true
  def handle_call(:received, _, state = %{received: received}) do
    {:reply, received, state}
  end

  @impl true
  def handle_info(info, state = %{received: received}) do
    {:noreply, %{state | received: [info | received]}}
  end

  defp track(invoice, state) do
    :ok = InvoiceEvents.subscribe(invoice)
    {:ok, invoice} = InvoiceManager.finalize_invoice(invoice)
    {:ok, handler} = InvoiceManager.get_handler(invoice.id)
    {:reply, {invoice, handler}, state}
  end
end
