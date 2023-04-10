defmodule BitPalApi.InvoiceView do
  use BitPalApi, :view
  alias BitPalSchemas.InvoiceRates
  alias BitPalApi.TransactionView
  alias BitPalSchemas.Invoice
  alias BitPalSchemas.InvoiceStatus

  def render("show.json", %{invoice: invoice = %Invoice{}}) do
    %{
      id: invoice.id,
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
    |> add_status(invoice)
    |> put_unless_empty(:rates, InvoiceRates.to_float(invoice.rates))
    |> put_unless_nil(:requiredConfirmations, invoice.required_confirmations)
    |> put_unless_nil(:paymentCurrency, invoice.payment_currency_id)
    |> put_expected_payment(invoice)
  end

  def render("index.json", %{invoices: invoices}) do
    Enum.map(invoices, fn invoice ->
      render("show.json", invoice: invoice)
    end)
  end

  def render("processing.json", data = %{id: id, txs: txs}) do
    %{
      id: id,
      txs: render_txs(txs)
    }
    |> add_status(data)
    |> put_unless_nil(:confirmations_due, data[:confirmations_due])
  end

  def render("uncollectible.json", data = %{id: id}) do
    %{id: id}
    |> add_status(data)
  end

  def render("underpaid.json", data = %{id: id, amount_due: amount_due, txs: txs}) do
    %{id: id, amount_due: Money.to_decimal(amount_due), txs: render_txs(txs)}
    |> add_status(data)
  end

  def render("overpaid.json", data = %{id: id, overpaid_amount: overpaid_amount, txs: txs}) do
    %{
      id: id,
      overpaid_amount: Money.to_decimal(overpaid_amount),
      txs: render_txs(txs)
    }
    |> add_status(data)
  end

  def render("paid.json", data = %{id: id}) do
    %{id: id}
    |> add_status(data)
  end

  def render("deleted.json", %{id: id}) do
    %{id: id, deleted: true}
  end

  def render("voided.json", data = %{id: id}) do
    %{id: id}
    |> add_status(data)
  end

  def render("finalized.json", invoice) do
    render("show.json", %{invoice: invoice})
  end

  defp render_txs(txs) do
    Enum.map(txs, fn tx -> TransactionView.render("show.json", tx: tx) end)
  end

  defp add_status(res, %{status: status}) do
    {state, reason} = InvoiceStatus.split(status)

    res
    |> Map.put(:status, state)
    |> put_unless_nil(:statusReason, reason)
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
