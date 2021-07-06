defmodule BitPal.InvoiceActionsTest do
  use BitPal.IntegrationCase

  setup do
    assert {:ok, invoice} =
             Invoices.register(%{
               amount: 1.2,
               exchange_rate: 2.0,
               currency: "BCH",
               fiat_currency: "USD"
             })

    %{invoice: invoice}
  end

  test "transitions", %{invoice: invoice} do
    assert invoice.status == :draft

    # Must have an address when finalizing
    assert {:error, _} = Invoices.finalize(invoice)
    assert {:ok, invoice} = Invoices.finalize(%{invoice | address_id: "some-address"})
    assert invoice.status == :open
  end
end
