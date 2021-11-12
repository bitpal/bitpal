defmodule BitPalFactory.SettingsFactoryTest do
  use BitPal.DataCase, async: true
  alias BitPal.Stores

  describe "address_key_fixture" do
    test "create" do
      address_key =
        create_address_key()
        |> Repo.preload(:currency_settings)

      assert address_key.currency_id
      assert Stores.fetch!(address_key.currency_settings.store_id)
    end

    test "with currency" do
      currency_id = unique_currency_id()
      address_key = create_address_key(currency_id: currency_id)
      assert address_key.currency_id == currency_id
    end

    test "with store" do
      store = create_store()

      address_key =
        create_address_key(store: store)
        |> Repo.preload(:currency_settings)

      assert address_key.currency_settings.store_id == store.id
    end

    test "with raw key data" do
      address_key = create_address_key(data: "myxpub")
      assert address_key.data == "myxpub"
    end
  end
end
