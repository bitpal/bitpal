defmodule BitPal.InvoiceEvents do
  @moduledoc """
  Invoice update events.
  """

  alias BitPal.EventHelpers
  alias BitPalSchemas.Invoice
  alias BitPalSchemas.TxOutput

  @type tx :: TxOutput.t()
  @type additional_confirmations :: non_neg_integer
  @type uncollectible_reason :: :expired | :canceled | :double_spent | :timed_out
  @type processing_reason :: :verifying | {:confirming, additional_confirmations}

  @type msg ::
          {{:invoice, :deleted}, %{id: Invoice.id(), status: Invoice.status()}}
          | {{:invoice, :finalized}, Invoice.t()}
          | {{:invoice, :voided}, %{id: Invoice.id(), status: Invoice.status()}}
          | {{:invoice, :uncollectible},
             %{id: Invoice.id(), status: Invoice.status(), reason: uncollectible_reason}}
          | {{:invoice, :underpaid},
             %{id: Invoice.id(), status: Invoice.status(), amount_due: Money.t(), txs: [tx]}}
          | {{:invoice, :overpaid},
             %{id: Invoice.id(), status: Invoice.status(), overpaid_amount: Money.t(), txs: [tx]}}
          | {{:invoice, :processing},
             %{id: Invoice.id(), status: Invoice.status(), reason: processing_reason, txs: [tx]}}
          | {{:invoice, :paid}, %{id: Invoice.id(), status: Invoice.status()}}

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
