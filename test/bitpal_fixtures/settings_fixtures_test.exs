defmodule BitPalFixtures.SettingsFixturesTest do
  use BitPal.DataCase, async: true
  alias BitPal.Stores

  describe "address_key_fixture" do
    test "create" do
      address_key =
        SettingsFixtures.address_key_fixture()
        |> Repo.preload(:currency_settings)

      assert address_key.currency_id
      assert Stores.fetch!(address_key.currency_settings.store_id)
    end

    test "with currency" do
      currency_id = unique_currency_id()
      address_key = SettingsFixtures.address_key_fixture(currency_id: currency_id)
      assert address_key.currency_id == currency_id
    end

    test "with store" do
      store = insert(:store)

      address_key =
        SettingsFixtures.address_key_fixture(store: store)
        |> Repo.preload(:currency_settings)

      assert address_key.currency_settings.store_id == store.id
    end

    test "with raw key data" do
      address_key = SettingsFixtures.address_key_fixture(data: "myxpub")
      assert address_key.data == "myxpub"
    end
  end
end
