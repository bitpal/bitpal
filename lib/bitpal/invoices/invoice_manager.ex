defmodule BitPal.InvoiceManager do
  use GenServer
  import BitPal.ConfigHelpers, only: [update_state: 3]
  alias BitPal.InvoiceHandler
  alias BitPal.Invoices
  alias BitPal.ProcessRegistry
  alias BitPalSchemas.Invoice
  alias Ecto.Changeset

  @supervisor BitPal.InvoiceSupervisor

  def start_link(opts) do
    GenServer.start(__MODULE__, opts, name: __MODULE__)
  end

  @spec finalize_invoice(Invoice.t()) :: {:ok, Invoice.t()} | {:error, Changeset.t()}
  def finalize_invoice(invoice) do
    with {:ok, invoice_id} <- finalize_and_track(invoice),
         {:ok, invoice} <- get_invoice(invoice_id) do
      {:ok, invoice}
    else
      err -> err
    end
  end

  @spec finalize_and_track(Invoice.t()) :: {:ok, Invoice.id()} | {:error, Changeset.t()}
  def finalize_and_track(invoice) do
    GenServer.call(__MODULE__, {:finalize_and_track, invoice.id})
    {:ok, invoice.id}
  end

  @spec count_children() :: non_neg_integer
  def count_children do
    Supervisor.count_children(@supervisor).workers
  end

  @spec configure([{:double_spend_timeout, non_neg_integer}]) :: :ok
  def configure(opts) do
    GenServer.call(__MODULE__, {:configure, opts})
  end

  @spec get_handler(Invoice.id()) :: {:ok, pid} | {:error, :not_found}
  def get_handler(invoice_id) do
    ProcessRegistry.get_process(InvoiceHandler.via_tuple(invoice_id))
  end

  @spec get_invoice(Invoice.id()) :: {:ok, Invoice.t()} | {:error, :not_found}
  def get_invoice(invoice_id) do
    case get_handler(invoice_id) do
      {:ok, handler} ->
        # Block until handler has finalized the invoice, which may change invoice details.
        invoice = InvoiceHandler.get_invoice(handler)
        # Must be ok, otherwise there's a bug somewhere
        if !Invoices.finalized?(invoice), do: raise("invoice not finalized yet!")
        {:ok, invoice}

      err ->
        err
    end
  end

  @spec tracked_invoices() :: [Invoice.t()]
  def tracked_invoices do
    DynamicSupervisor.which_children(@supervisor)
    |> Enum.map(fn {_, pid, _, _} ->
      pid
      |> InvoiceHandler.get_invoice()
    end)
  end

  @spec terminate_children() :: :ok
  def terminate_children do
    DynamicSupervisor.which_children(@supervisor)
    |> Enum.each(fn {_, pid, _, _} ->
      DynamicSupervisor.terminate_child(@supervisor, pid)
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
  def handle_call({:finalize_and_track, invoice_id}, _from, state) do
    child =
      DynamicSupervisor.start_child(
        @supervisor,
        {InvoiceHandler, invoice_id: invoice_id, double_spend_timeout: state.double_spend_timeout}
      )

    {:reply, child, state}
  end

  @impl true
  def handle_call({:configure, opts}, _, state) do
    # We could change configs of handlers as well, but the only thing we can change
    # is `double_spend_timeout` which will be very fast, so it doesn't matter much in practice.
    {:reply, :ok, update_state(state, opts, :double_spend_timeout)}
  end
end
