defmodule BitPalFixtures.AddressFixturesTest do
  use BitPal.DataCase, async: true
  alias BitPal.Currencies

  setup _tags do
    %{store: StoreFixtures.store_fixture()}
  end

  describe "unique_address_id" do
    test "BCH cashaddress", %{store: store} do
      currency_id = CurrencyFixtures.currency_id(:BCH)
      assert "bitcoincash:" <> _ = AddressFixtures.unique_address_id(store.id, currency_id)
    end

    test "generate addresses", %{store: store} do
      for currency_id <- Currencies.supported_currencies() do
        test_unique_addresses(store.id, currency_id)
      end
    end
  end

  def test_unique_addresses(store_id, currency_id) do
    Enum.reduce(0..20, MapSet.new(), fn _, seen ->
      address = AddressFixtures.unique_address_id(store_id, currency_id)
      assert !MapSet.member?(seen, address), "Duplicate addresses generated #{currency_id}"
      MapSet.put(seen, address)
    end)
  end
end
