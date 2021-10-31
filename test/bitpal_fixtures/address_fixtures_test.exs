defmodule BitPalFixtures.AddressFixturesTest do
  use BitPal.DataCase, async: true
  import BitPalFixtures.AddressFixtures

  setup tags do
    invoice =
      StoreFixtures.store_fixture()
      |> InvoiceFixtures.invoice_fixture()

    %{invoice: invoice}
  end

  test "unique addresses", %{invoice: invoice} do
    IO.inspect(invoice)
  end
end
