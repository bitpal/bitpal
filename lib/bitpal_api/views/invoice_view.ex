defmodule BitPalApi.InvoiceView do
  use BitPalApi, :view
  alias BitPalApi.TransactionView
  alias BitPalSchemas.Invoice

  def render("show.json", %{invoice: invoice = %Invoice{}}) do
    %{
      id: invoice.id,
      currency: invoice.currency_id,
      address: invoice.address_id,
      status: invoice.status,
      required_confirmations: invoice.required_confirmations,
      email: invoice.email,
      description: invoice.description,
      pos_data: invoice.pos_data
    }
    |> put_unless_nil(:amount, invoice.amount, &Money.to_decimal/1)
    |> put_unless_nil(:fiat_amount, invoice.fiat_amount, &Money.to_decimal/1)
    |> put_unless_nil(:fiat_currency, invoice.fiat_amount, & &1.currency)
  end

  def render("index.json", %{invoices: invoices}) do
    Enum.map(invoices, fn invoice ->
      render("show.json", invoice: invoice)
    end)
  end

  def render("processing.json", %{id: id, status: status, reason: reason, txs: txs}) do
    %{
      id: id,
      status: status,
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

  def render("uncollectible.json", %{id: id, status: status, reason: reason}) do
    %{id: id, status: status, reason: Atom.to_string(reason)}
  end

  def render("underpaid.json", %{id: id, status: status, amount_due: amount_due, txs: txs}) do
    %{id: id, status: status, amount_due: Money.to_decimal(amount_due), txs: render_txs(txs)}
  end

  def render("overpaid.json", %{
        id: id,
        status: status,
        overpaid_amount: overpaid_amount,
        txs: txs
      }) do
    %{
      id: id,
      status: status,
      overpaid_amount: Money.to_decimal(overpaid_amount),
      txs: render_txs(txs)
    }
  end

  def render("paid.json", %{id: id, status: status}) do
    %{id: id, status: status}
  end

  def render("deleted.json", %{id: id, deleted: deleted}) do
    %{id: id, deleted: deleted}
  end

  defp render_txs(txs) do
    Enum.map(txs, fn tx -> TransactionView.render("show.json", tx: tx) end)
  end
end
