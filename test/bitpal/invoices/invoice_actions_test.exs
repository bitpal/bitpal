defmodule BitPal.InvoiceActionsTest do
  use BitPal.IntegrationCase

  setup do
    assert {:ok, invoice} =
             Invoices.register(%{
               amount: Money.parse!(1.2, :BCH),
               exchange_rate: ExchangeRate.new!(Decimal.from_float(2.0), {:BCH, :USD})
             })

    %{invoice: invoice}
  end

  test "transitions", %{invoice: invoice} do
    assert invoice.status == :draft

    assert {:ok, invoice} = Invoices.finalize(invoice)
    assert invoice.status == :open
  end
end
