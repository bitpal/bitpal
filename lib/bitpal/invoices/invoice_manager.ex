defmodule BitPal.InvoiceManager do
  use GenServer
  alias BitPal.Invoice
  alias BitPal.InvoiceHandler

  @supervisor BitPal.InvoiceSupervisor

  def start_link(opts) do
    GenServer.start(__MODULE__, opts, name: __MODULE__)
  end

  @spec create_invoice(Invoice.t()) :: {:ok, pid}
  def create_invoice(invoice) do
    GenServer.call(__MODULE__, {:create_invoice, invoice})
  end

  @spec create_invoice_and_subscribe(Invoice.t()) :: {:ok, pid}
  def create_invoice_and_subscribe(invoice) do
    {:ok, pid} = create_invoice(invoice)
    InvoiceHandler.subscribe_and_get_current(pid)
    {:ok, pid}
  end

  @spec count_children() :: non_neg_integer
  def count_children() do
    Supervisor.count_children(@supervisor).workers
  end

  def tracked_invoices() do
    DynamicSupervisor.which_children(@supervisor)
    |> Enum.map(fn {_, pid, _, _} ->
      InvoiceHandler.get_invoice(pid)
    end)
  end

  @impl true
  def init(opts) do
    # Internal supervisor to reduce the number of modules and it's not doing much
    DynamicSupervisor.start_link(strategy: :one_for_one, name: @supervisor)

    put_new_env = fn map, key, default ->
      Map.put_new_lazy(map, key, fn -> Application.get_env(:bitpal, key, default) end)
    end

    settings =
      opts
      |> Enum.into(%{})
      |> put_new_env.(:double_spend_timeout, 2_000)

    {:ok, settings}
  end

  @impl true
  def handle_call({:create_invoice, invoice}, _from, state) do
    child =
      DynamicSupervisor.start_child(
        @supervisor,
        {InvoiceHandler, invoice: invoice, double_spend_timeout: state.double_spend_timeout}
      )

    {:reply, child, state}
  end
end
