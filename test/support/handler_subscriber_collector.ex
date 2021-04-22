defmodule HandlerSubscriberCollector do
  use GenServer
  alias BitPal.Invoice
  alias BitPal.InvoiceManager
  alias BitPal.InvoiceHandler

  # Client API

  @spec create_invoice(Invoice.t()) :: {:ok, Invoice.t(), pid, pid}
  def create_invoice(invoice) do
    {:ok, stub} = start_link(nil)

    {invoice, handler} = GenServer.call(stub, {:create_invoice, invoice})

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

  def await_endstate(handler, state, invoice) do
    await_msg(handler, {:state, state, invoice})
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
  def handle_call({:create_invoice, invoice}, _, state) do
    {:ok, handler} = InvoiceManager.create_invoice_and_subscribe(invoice)

    invoice = InvoiceHandler.get_invoice(handler)

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
