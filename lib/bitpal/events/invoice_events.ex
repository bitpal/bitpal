defmodule BitPal.InvoiceEvents do
  @moduledoc """
  Invoice update events.
  """

  alias BitPal.EventHelpers
  alias BitPalSchemas.Invoice

  @type msg :: {:invoice_status, Invoice.status(), Invoice.t()}

  @spec subscribe(Invoice.id() | Invoice.t()) :: :ok | {:error, term}
  def subscribe(%Invoice{id: id}), do: EventHelpers.subscribe(topic(id))
  def subscribe(id), do: EventHelpers.subscribe(topic(id))

  @spec broadcast_status(Invoice.t()) :: :ok | {:error, term}
  def broadcast_status(invoice) do
    EventHelpers.broadcast(topic(invoice.id), {:invoice_status, invoice.status, invoice})
  end

  @spec topic(Invoice.id()) :: binary
  defp topic(invoice_id) do
    "invoice:" <> invoice_id
  end
end
