defmodule BitPal.HandlerSubscriberCollector do
  use GenServer
  alias BitPal.InvoiceEvents
  alias BitPal.InvoiceManager
  alias BitPal.Invoices
  alias BitPalFixtures.InvoiceFixtures
  alias BitPalFixtures.SettingsFixtures
  alias BitPal.ProcessRegistry

  # Client API

  def create_invoice(opts \\ %{}) do
    opts = Enum.into(opts, %{})

    # Create invoice outside of the server process to generate unique names from the invoice id.
    invoice = InvoiceFixtures.invoice_fixture(opts)

    # Fixture may have created an address_key, but it's not guaranteed.
    # This is needed when finalizing, so generate one if needed.
    case Invoices.address_key(invoice) do
      {:ok, _} ->
        nil

      {:error, :not_found} ->
        SettingsFixtures.address_key_fixture(invoice)
    end

    {:ok, stub} = GenServer.start_link(__MODULE__, name: via_tuple(invoice.id), parent: self())
    {invoice, handler} = GenServer.call(stub, {:track_invoice, invoice, opts})

    {:ok, invoice, stub, handler}
  end

  defp via_tuple(invoice_id) do
    ProcessRegistry.via_tuple({__MODULE__, invoice_id})
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
  def init(args) do
    parent = Keyword.fetch!(args, :parent)
    Ecto.Adapters.SQL.Sandbox.allow(BitPal.Repo, parent, self())

    {:ok, %{received: [], parent: parent}}
  end

  @impl true
  def handle_call({:track_invoice, invoice, opts}, _, state) do
    :ok = InvoiceEvents.subscribe(invoice)

    {:ok, invoice} =
      InvoiceManager.finalize_invoice(invoice,
        parent: state.parent,
        double_spend_timeout: opts[:double_spend_timeout],
        manager_name: opts[:manager_name] || BitPal.BackendManager
      )

    {:ok, handler} = InvoiceManager.fetch_handler(invoice.id)

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
