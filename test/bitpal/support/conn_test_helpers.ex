defmodule BitPal.ConnTestHelpers do
  alias BitPalFixtures.InvoiceFixtures

  def create_invoice(context = %{conn: conn = %Plug.Conn{}}, attrs \\ []) do
    attrs = Enum.into(attrs, %{currency_id: context[:currency_id]})
    invoice = InvoiceFixtures.invoice_fixture(conn, attrs)

    # All these just makes some tests a little easier to write
    Map.merge(context, %{
      invoice: invoice,
      invoice_id: invoice.id,
      store_id: invoice.store_id,
      address_id: invoice.address_id,
      currency_id: invoice.currency_id
    })
  end
end
