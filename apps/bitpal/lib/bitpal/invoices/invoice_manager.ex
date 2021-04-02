defmodule BitPal.InvoiceManager do
  use DynamicSupervisor
  alias BitPal.Invoice
  alias BitPal.InvoiceHandler
  alias BitPal.InvoiceEvent

  # @type invoice_id :: binary

  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec create_invoice(Invoice.t()) :: {:ok, pid}
  def create_invoice(invoice) do
    # FIXME should generate an invoice_id here
    # makes sense to do it when we persist to db
    InvoiceEvent.subscribe(invoice)

    {:ok, _} =
      DynamicSupervisor.start_child(
        __MODULE__,
        {InvoiceHandler, invoice: invoice}
      )
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
