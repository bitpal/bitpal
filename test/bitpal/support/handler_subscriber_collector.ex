defmodule BitPal.HandlerSubscriberCollector do
  use GenServer
  alias BitPal.InvoiceEvents
  alias BitPal.Invoices
  alias BitPal.InvoiceSupervisor
  alias BitPal.ProcessRegistry
  alias BitPalFactory.InvoiceFactory
  alias BitPalFactory.SettingsFactory
  alias Ecto.Adapters.SQL.Sandbox

  # Client API

  def create_invoice(opts \\ %{}) do
    opts = Enum.into(opts, %{})

    # Create invoice outside of the server process to generate unique names from the invoice id.
    invoice = InvoiceFactory.create_invoice(Map.put(opts, :status, :draft))

    # Factories may have created an address_key, but it's not guaranteed.
    # This is needed when finalizing, so generate one if needed.
    case Invoices.address_key(invoice) do
      {:ok, _} ->
        nil

      {:error, :not_found} ->
        SettingsFactory.create_address_key(invoice)
    end

    {:ok, stub} = GenServer.start_link(__MODULE__, name: via_tuple(invoice.id), parent: self())
    {invoice, handler} = track_and_finalize(stub, invoice, opts)

    {:ok, invoice, stub, handler}
  end

  defp track_and_finalize(stub, invoice, opts) do
    GenServer.call(stub, {:track_and_finalize, invoice, opts})
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
    |> Task.await(1_000)

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

  def paid?(handler) do
    contains_id?(handler, {:invoice, :paid})
  end

  # Server API

  @impl true
  def init(args) do
    parent = Keyword.fetch!(args, :parent)
    Sandbox.allow(BitPal.Repo, parent, self())

    {:ok, %{received: [], parent: parent}}
  end

  @impl true
  def handle_call({:track_and_finalize, invoice, opts}, _, state) do
    :ok = InvoiceEvents.subscribe(invoice)
    invoice = ensure_tracked_and_finalized(invoice, opts, state)
    {:ok, handler} = InvoiceSupervisor.fetch_handler(invoice.id)
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

  defp ensure_tracked_and_finalized(invoice, opts, state) do
    manager_opts = %{
      parent: state.parent,
      double_spend_timeout: opts[:double_spend_timeout],
      manager: opts[:manager] || BitPal.BackendManager,
      restart: opts[:restart] || :transient
    }

    if Invoices.finalized?(invoice) do
      {:ok, _} = InvoiceSupervisor.ensure_handler(invoice, manager_opts)
      invoice
    else
      {:ok, invoice} = InvoiceSupervisor.finalize_invoice(invoice, manager_opts)
      invoice
    end
  end
end
