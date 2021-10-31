defmodule BitPalFixtures.AddressFixturesTest do
  use BitPal.DataCase, async: true
  alias BitPal.Invoices
  alias BitPalSettings.StoreSettings
  alias BitPalSchemas.Address

  describe "address_fixture" do
    test "generate all" do
      address = AddressFixtures.address_fixture()
      assert Repo.get!(Address, address.id).id == address.id
      assert is_binary(address.id)
    end

    test "existing address_id" do
      address_id = AddressFixtures.unique_address_id()
      address = AddressFixtures.address_fixture(address_id: address_id)
      assert address.id == address_id
    end

    test "existing currency_id" do
      currency_id = CurrencyFixtures.unique_currency_id()
      address = AddressFixtures.address_fixture(currency_id: currency_id)
      assert address.currency_id == currency_id
    end

    test "assoc invoice" do
      invoice = InvoiceFixtures.invoice_fixture()
      address = AddressFixtures.address_fixture(invoice: invoice)
      assert address.currency_id == invoice.currency_id
      {:ok, got_invoice} = Invoices.fetch_by_address(address.id)
      assert got_invoice.id == invoice.id
    end

    test "assoc address_key" do
      address_key = SettingsFixtures.address_key_fixture()
      address = AddressFixtures.address_fixture(address_key: address_key)
      assert address.address_key_id == address_key.id
    end

    test "assoc address_key via store and currency_id" do
      store = StoreFixtures.store_fixture()
      currency_id = CurrencyFixtures.unique_currency_id()
      address = AddressFixtures.address_fixture(store: store, currency_id: currency_id)
      address_key = StoreSettings.fetch_address_key!(store.id, currency_id)
      assert address.address_key_id == address_key.id
    end

    test "unique addresses" do
      store = StoreFixtures.store_fixture()
      currency_id = CurrencyFixtures.unique_currency_id()

      Enum.reduce(0..4, MapSet.new(), fn _, seen ->
        address_id = AddressFixtures.address_fixture(store: store, currency_id: currency_id).id

        assert !MapSet.member?(seen, address_id),
               "Duplicate addresses generated #{currency_id} #{address_id}"

        MapSet.put(seen, address_id)
      end)
    end
  end
end
