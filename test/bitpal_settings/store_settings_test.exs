defmodule BitPalSettings.StoreSettingsTest do
  use BitPal.DataCase, async: true
  alias BitPalSettings.StoreSettings
  alias BitPalSchemas.AddressKey

  setup _tags do
    %{store: insert(:store), currency_id: unique_currency_id()}
  end

  describe "address_key" do
    test "set then fetch", %{store: store, currency_id: currency_id} do
      assert {:ok, _} = StoreSettings.set_address_key(store.id, currency_id, "myxpub")
      assert StoreSettings.fetch_address_key!(store.id, currency_id).data == "myxpub"
    end

    test "update if no addresses has been generated", %{store: store, currency_id: currency_id} do
      default_key =
        SettingsFixtures.address_key_fixture(%{store: store, currency_id: currency_id})

      assert {:ok, new_key} = StoreSettings.set_address_key(store.id, currency_id, "myxpub")
      assert new_key.id == default_key.id
      assert StoreSettings.fetch_address_key!(store.id, currency_id).data == "myxpub"
    end

    test "insert a new if address references exists", %{store: store, currency_id: currency_id} do
      default_key =
        SettingsFixtures.address_key_fixture(%{store: store, currency_id: currency_id})

      assert AddressFixtures.address_fixture(default_key)

      assert {:ok, new_key} = StoreSettings.set_address_key(store.id, currency_id, "myxpub")
      assert new_key.id != default_key.id
      assert StoreSettings.fetch_address_key!(store.id, currency_id).data == "myxpub"

      # The old one should be disconnected from the settings
      address_key = Repo.get!(AddressKey, default_key.id)
      assert address_key.currency_settings_id == nil
    end
  end

  describe "simple settings" do
    test "required_confirmations", %{store: store, currency_id: currency_id} do
      assert StoreSettings.get_required_confirmations(store.id, currency_id) >= 0
      assert {:ok, _} = StoreSettings.set_required_confirmations(store.id, currency_id, 3)
      assert StoreSettings.get_required_confirmations(store.id, currency_id) == 3
    end

    test "double_spend_timeouts", %{store: store, currency_id: currency_id} do
      assert StoreSettings.get_double_spend_timeout(store.id, currency_id) > 0
      assert {:ok, _} = StoreSettings.set_double_spend_timeout(store.id, currency_id, 5_000)
      assert StoreSettings.get_double_spend_timeout(store.id, currency_id) == 5_000
    end
  end
end
