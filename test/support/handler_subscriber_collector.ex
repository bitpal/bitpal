defmodule HandlerSubscriberCollector do
  use GenServer
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
          currency: :bch,
          amount: 1.3,
          exchange_rate: {2.0, "BCH"},
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

  def await_state(handler, state) do
    await_msg(handler, {:state, state})
  end

  def await_msg(handler, msg) do
    Task.async(__MODULE__, :sleep_until_msg, [handler, msg])
    |> Task.await(50)

    {:ok, received(handler)}
  end

  def sleep_until_msg(handler, msg) do
    if contains_msg?(handler, msg) do
      :ok
    else
      Process.sleep(10)
      sleep_until_msg(handler, msg)
    end
  end

  def contains_msg?(handler, msg) do
    received(handler)
    |> Enum.any?(fn x -> x == msg end)
  end

  def is_accepted?(handler) do
    contains_msg?(handler, {:state, :accepted})
  end

  # Server API

  @impl true
  def init(_init_args) do
    {:ok, %{received: []}}
  end

  @impl true
  def handle_call({:create_invoice, params}, _, state) do
    {:ok, invoice_id} = InvoiceManager.register_invoice(params)

    {:ok, handler} = InvoiceManager.get_handler(invoice_id)
    # Block until handler has initialized, which may change invoice details.
    _ = InvoiceHandler.get_invoice_id(handler)
    invoice = Invoices.get(invoice_id)

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
