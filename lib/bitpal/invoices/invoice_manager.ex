defmodule BitPal.InvoiceManager do
  use DynamicSupervisor
  alias BitPal.InvoiceHandler
  alias BitPal.Invoices
  alias BitPal.ProcessRegistry
  alias BitPalSchemas.Invoice
  alias Ecto.Changeset

  @type server_name :: atom | {:via, term, term}

  @spec start_link(keyword) :: DynamicSupervisor.on_start()
  def start_link(opts) do
    name = opts[:name] || __MODULE__
    DynamicSupervisor.start_link(__MODULE__, opts, name: name)
  end

  def child_spec(opts) do
    %{
      id: opts[:name] || __MODULE__,
      restart: :transient,
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  # Individual invoices

  @spec finalize_invoice(Invoice.t(), keyword | map) ::
          {:ok, Invoice.t()} | {:error, Changeset.t()}
  def finalize_invoice(invoice = %Invoice{}, opts \\ []) do
    opts =
      Enum.into(opts, %{
        parent: self()
      })

    # The handler will finalize and update the invoice, so we'll need to fetch the
    # updated invoice from the handler.
    with {:ok, handler} <- start_handler(invoice, opts),
         {:ok, invoice} <- fetch_invoice(handler) do
      {:ok, invoice}
    else
      err -> err
    end
  end

  defp start_handler(invoice, opts) do
    name = opts[:name] || __MODULE__

    DynamicSupervisor.start_child(
      name,
      {
        InvoiceHandler,
        manager_name: opts[:manager_name],
        parent: opts[:parent],
        invoice_id: invoice.id,
        double_spend_timeout:
          opts[:double_spend_timeout] || Invoices.double_spend_timeout(invoice)
      }
    )
  end

  @spec ensure_handler(Invoice.t(), keyword | map) :: {:ok, pid} | {:error, term}
  def ensure_handler(invoice, opts) do
    case fetch_handler(invoice.id) do
      handler = {:ok, _} -> handler
      {:error, _} -> start_handler(invoice, opts)
    end
  end

  @spec fetch_handler(Invoice.id()) :: {:ok, pid} | {:error, :not_found}
  def fetch_handler(invoice_id) do
    ProcessRegistry.get_process(InvoiceHandler.via_tuple(invoice_id))
  end

  @spec fetch_invoice(pid | Invoice.id()) :: {:ok, Invoice.t()} | {:error, :not_found}
  def fetch_invoice(handler) when is_pid(handler) do
    # Blocks until handler has finalized the invoice, which may change invoice details.
    case InvoiceHandler.fetch_invoice(handler) do
      {:ok, invoice} ->
        InvoiceHandler.fetch_invoice(handler)
        # Must be finalized, otherwise there's a logic bug somewhere when initializing handler.
        if !Invoices.finalized?(invoice), do: raise("invoice not finalized yet!")
        {:ok, invoice}

      _ ->
        {:error, :not_found}
    end
  end

  def fetch_invoice(invoice_id) do
    case fetch_handler(invoice_id) do
      {:ok, handler} ->
        fetch_invoice(handler)

      _ ->
        {:error, :not_found}
    end
  end

  @spec fetch_or_load_invoice(Invoice.id()) :: {:ok, Invoice.t()} | {:error, :not_found}
  def fetch_or_load_invoice(invoice_id) do
    case fetch_invoice(invoice_id) do
      {:ok, invoice} -> {:ok, invoice}
      _ -> Invoices.fetch(invoice_id)
    end
  end

  # Supervision

  @spec count_children(server_name) :: non_neg_integer
  def count_children(name \\ __MODULE__) do
    DynamicSupervisor.count_children(name).workers
  end

  @spec tracked_invoices() :: [Invoice.t()]
  def tracked_invoices(name \\ __MODULE__) do
    DynamicSupervisor.which_children(name)
    |> Enum.map(fn {_, pid, _, _} ->
      pid
      |> InvoiceHandler.fetch_invoice!()
    end)
  end

  @spec terminate_handler(pid) :: :ok | {:error, :not_found}
  def terminate_handler(name \\ __MODULE__, pid) do
    DynamicSupervisor.terminate_child(name, pid)
  end

  # Server API

  @impl true
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
