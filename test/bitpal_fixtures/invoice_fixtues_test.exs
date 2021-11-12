defmodule BitPalFixtures.InvoiceFixturesTest do
  use BitPal.IntegrationCase, async: true
  alias BitPalSettings.StoreSettings

  setup _tags do
    %{store: Factory.insert(:store)}
  end

  describe "invoice_fixture/2" do
    test "inserts into db", %{store: store} do
      invoice = InvoiceFixtures.invoice_fixture(store: store)
      assert {:ok, _} = BitPal.Invoices.fetch(invoice.id)
    end

    test "different ways of specifying store", %{store: store} do
      assert InvoiceFixtures.invoice_fixture(store).store_id == store.id
      assert InvoiceFixtures.invoice_fixture(store: store).store_id == store.id
      assert InvoiceFixtures.invoice_fixture(store_id: store.id).store_id == store.id
    end

    test "create store if not specified" do
      assert InvoiceFixtures.invoice_fixture().store_id != nil
    end

    test "assigns existing address", %{store: store} do
      currency_id = CurrencyFixtures.unique_currency_id()
      address = AddressFixtures.address_fixture(store_id: store.id, currency_id: currency_id)

      assert InvoiceFixtures.invoice_fixture(store, address: address.id, currency_id: currency_id).address_id ==
               address.id
    end

    test "assigns address_id and creates an Address", %{store: store} do
      address_id = AddressFixtures.unique_address_id()
      invoice = InvoiceFixtures.invoice_fixture(store, address: address_id)
      assert invoice.address_id == address_id
      assert Addresses.get(address_id) != nil
    end

    test "generates address with auto", %{store: store} do
      invoice = InvoiceFixtures.invoice_fixture(store, address: :auto)
      assert invoice.address_id != nil
      assert Addresses.get(invoice.address_id) != nil
    end

    test "specify currency" do
      currency_id = CurrencyFixtures.unique_currency_id()
      assert InvoiceFixtures.invoice_fixture(currency_id: currency_id).currency_id == currency_id
    end

    test "specify xpub", %{store: store} do
      xpub = "myxpub"
      invoice = InvoiceFixtures.invoice_fixture(store: store, address_key: xpub)
      address_key = StoreSettings.fetch_address_key!(store.id, invoice.currency_id)
      assert address_key.data == xpub
      {:ok, got_address_key} = Invoices.address_key(invoice)
      assert got_address_key.id == address_key.id
    end
  end

  describe "ensure_address/2" do
    setup %{store: store} do
      %{store: store, invoice: InvoiceFixtures.invoice_fixture(store)}
    end

    test "pass through existing address", %{store: store, invoice: invoice} do
      address =
        AddressFixtures.address_fixture(store_id: store.id, currency_id: invoice.currency_id)

      invoice = InvoiceFixtures.ensure_address(invoice, address: address.id)
      assert invoice.address_id == address.id
    end

    test "create address_id", %{invoice: invoice} do
      address_id = AddressFixtures.unique_address_id()
      invoice = InvoiceFixtures.ensure_address(invoice, address: address_id)
      assert invoice.address_id == address_id
      assert Addresses.get(address_id) != nil
    end

    test "generates an address if nothing specified", %{invoice: invoice} do
      invoice = InvoiceFixtures.ensure_address(invoice)
      assert invoice.address_id != nil
      assert Addresses.get(invoice.address_id) != nil
    end
  end
end
