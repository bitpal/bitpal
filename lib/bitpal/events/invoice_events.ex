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
          {:invoice_deleted, %{id: Invoice.id()}}
          | {:invoice_finalized, Invoice.t()}
          | {:invoice_voided, %{id: Invoice.id()}}
          | {:invoice_uncollectible, %{id: Invoice.id(), reason: uncollectible_reason}}
          | {:invoice_underpaid, %{id: Invoice.id(), amount_due: Money.t(), txs: [tx]}}
          | {:invoice_overpaid, %{id: Invoice.id(), overpaid_amount: Money.t(), txs: [tx]}}
          | {:invoice_processing, %{id: Invoice.id(), reason: processing_reason, txs: [tx]}}
          | {:invoice_paid, %{id: Invoice.id()}}

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
