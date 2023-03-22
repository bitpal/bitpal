defmodule BitPalApi.InvoiceView do
  use BitPalApi, :view
  alias BitPalSchemas.InvoiceRates
  alias BitPalApi.TransactionView
  alias BitPalSchemas.Invoice
  alias BitPalSchemas.InvoiceStatus

  def render("show.json", %{invoice: invoice = %Invoice{}}) do
    {state, reason} = InvoiceStatus.split(invoice.status)

    %{
      id: invoice.id,
      status: state,
      priceCurrency: invoice.price.currency,
      price: Decimal.to_string(Money.to_decimal(invoice.price) |> Decimal.normalize(), :normal),
      priceDisplay: money_to_string(invoice.price),
      subPrice: invoice.price.amount,
      address: invoice.address_id,
      email: invoice.email,
      description: invoice.description,
      orderId: invoice.order_id,
      posData: invoice.pos_data
    }
    |> put_unless_empty(:rates, InvoiceRates.to_float(invoice.rates))
    |> put_unless_nil(:statusReason, reason)
    |> put_unless_nil(:requiredConfirmations, invoice.required_confirmations)
    |> put_unless_nil(:paymentCurrency, invoice.payment_currency_id)
    |> put_expected_payment(invoice)
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

  defp put_expected_payment(params, %{expected_payment: expected_payment})
       when not is_nil(expected_payment) do
    Map.merge(params, %{
      paymentSubAmount: expected_payment.amount,
      paymentDisplay: money_to_string(expected_payment)
    })
  end

  defp put_expected_payment(params, _) do
    params
  end
end
