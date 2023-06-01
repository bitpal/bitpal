defmodule BitPalApi.InvoiceJSON do
  use BitPalApi, :json
  alias BitPalSchemas.InvoiceRates
  alias BitPalApi.TransactionJSON
  alias BitPalSchemas.Invoice
  alias BitPalSchemas.InvoiceStatus

  def show(%{invoice: invoice = %Invoice{}}) do
    %{
      id: invoice.id,
      price: Decimal.to_float(Money.to_decimal(invoice.price) |> Decimal.normalize()),
      priceCurrency: invoice.price.currency,
      priceDisplay: money_to_string(invoice.price),
      priceSubAmount: invoice.price.amount,
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
    |> add_paid(invoice)
  end

  def index(%{invoices: invoices}) do
    Enum.map(invoices, fn invoice ->
      show(%{invoice: invoice})
    end)
  end

  def processing(data = %{id: id, txs: txs}) do
    %{
      id: id,
      txs: render_txs(txs)
    }
    |> add_status(data)
    |> put_unless_nil(:confirmationsDue, data[:confirmations_due])
  end

  def uncollectible(data = %{id: id}) do
    %{id: id}
    |> add_status(data)
  end

  def underpaid(data) do
    render_pay_update(data)
  end

  def overpaid(data) do
    render_pay_update(data)
  end

  def paid(data) do
    render_pay_update(data)
  end

  def deleted(%{id: id}) do
    %{id: id, deleted: true}
  end

  def voided(data = %{id: id}) do
    %{id: id}
    |> add_status(data)
  end

  def finalized(invoice) do
    show(%{invoice: invoice})
  end

  defp render_pay_update(data = %{id: id}) do
    %{id: id}
    |> add_paid(data)
    |> add_status(data)
    |> add_txs(data)
  end

  defp add_paid(res, %{payment_currency_id: nil}) do
    res
  end

  defp add_paid(res, %{amount_paid: nil}) do
    res
  end

  defp add_paid(res, %{amount_paid: paid}) do
    res
    |> Map.put(:paidDisplay, money_to_string(paid))
    |> Map.put(:paidSubAmount, paid.amount)
  end

  defp add_txs(res, %{txs: txs}) do
    res
    |> Map.put(:txs, render_txs(txs))
  end

  defp render_txs(txs) do
    Enum.map(txs, fn tx -> TransactionJSON.show(tx) end)
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
