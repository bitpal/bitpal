defmodule BitPalApi.InvoiceView do
  use BitPalApi, :view
  alias BitPalApi.TransactionView
  alias BitPalSchemas.Invoice

  def render("show.json", %{invoice: invoice = %Invoice{}}) do
    %{
      id: invoice.id,
      amount: Money.to_decimal(invoice.amount),
      currency: invoice.currency_id,
      fiat_amount: Money.to_decimal(invoice.fiat_amount),
      fiat_currency: invoice.fiat_amount.currency,
      address: invoice.address_id,
      status: invoice.status,
      required_confirmations: invoice.required_confirmations
    }
  end

  def render("processing.json", %{id: id, reason: reason, txs: txs}) do
    %{
      id: id,
      txs: render_txs(txs)
    }
    |> then(fn res ->
      case reason do
        {:confirming, confirmations_due} ->
          res
          |> Map.put(:reason, "confirming")
          |> Map.put(:confirmations_due, confirmations_due)

        :verifying ->
          Map.put(res, :reason, "verifying")
      end
    end)
  end

  def render("uncollectible.json", %{id: id, reason: reason}) do
    %{id: id, reason: Atom.to_string(reason)}
  end

  def render("underpaid.json", %{id: id, amount_due: amount_due, txs: txs}) do
    %{id: id, amount_due: Money.to_decimal(amount_due), txs: render_txs(txs)}
  end

  def render("overpaid.json", %{id: id, overpaid_amount: overpaid_amount, txs: txs}) do
    %{id: id, overpaid_amount: Money.to_decimal(overpaid_amount), txs: render_txs(txs)}
  end

  def render("paid.json", %{id: id}) do
    %{id: id}
  end

  defp render_txs(txs) do
    Enum.map(txs, fn tx -> TransactionView.render("show.json", tx: tx) end)
  end
end
