defmodule BitPal.InvoiceEvents do
  @moduledoc """
  Invoice update events.
  """

  alias BitPal.EventHelpers
  alias BitPalSchemas.Invoice
  alias BitPalSchemas.InvoiceStatus

  @type tx :: Transaction.t()
  @type txinfo :: %{
          txid: Transaction.id(),
          height: Transaction.height(),
          failed: boolean,
          double_spent: boolean,
          amount: Money.t(),
          address_id: Address.id()
        }
  @type txs :: [txinfo]
  @type additional_confirmations :: non_neg_integer

  @type msg ::
          {{:invoice, :deleted}, %{id: Invoice.id(), status: InvoiceStatus.t()}}
          | {{:invoice, :finalized}, Invoice.t()}
          | {{:invoice, :voided}, %{id: Invoice.id(), status: InvoiceStatus.t()}}
          | {{:invoice, :uncollectible}, %{id: Invoice.id(), status: InvoiceStatus.t()}}
          | {
              {:invoice, :underpaid},
              %{id: Invoice.id(), status: InvoiceStatus.t(), amount_paid: Money.t(), txs: txs}
            }
          | {
              {:invoice, :overpaid},
              %{id: Invoice.id(), status: InvoiceStatus.t(), amount_paid: Money.t(), txs: txs}
            }
          | {{:invoice, :processing},
             %{
               id: Invoice.id(),
               status: InvoiceStatus.t(),
               confirmations_due: additional_confirmations,
               txs: txs
             }}
          | {{:invoice, :paid},
             %{id: Invoice.id(), status: InvoiceStatus.t(), amount_paid: Money.t(), txs: txs}}

  @spec subscribe(Invoice.id() | Invoice.t()) :: :ok | {:error, term}
  def subscribe(%Invoice{id: id}), do: EventHelpers.subscribe(topic(id))
  def subscribe(id), do: EventHelpers.subscribe(topic(id))

  @spec broadcast(msg) :: :ok | {:error, term}
  def broadcast(msg = {_, %{id: id}}) do
    EventHelpers.broadcast(topic(id), msg)
  end

  @spec topic(Invoice.id()) :: binary
  defp topic(invoice_id) do
    "invoice:" <> invoice_id
  end
end
