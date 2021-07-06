defmodule BitPal.InvoiceFetchingTest do
  use BitPal.IntegrationCase

  defp invoice(address_id) do
    {:ok, address} = Addresses.register_next_address("BCH", address_id)

    {:ok, invoice} =
      Invoices.register(%{
        amount: Money.parse!(1.2, "BCH"),
        exchange_rate: ExchangeRate.new!(Decimal.from_float(2.0), {"BCH", "USD"})
      })

    {:ok, invoice} = Invoices.assign_address(invoice, address)

    invoice
  end

  test "filter addresses" do
    draft_invoice = invoice("one")
    open_invoice = invoice("two") |> Invoices.finalize!()
    processing_invoice_invoice = invoice("three") |> Invoices.finalize!() |> Invoices.process!()

    assert ["two"] == Invoices.open_addresses(:BCH)
    assert ["two", "three"] == Invoices.active_addresses(:BCH)
  end
end
