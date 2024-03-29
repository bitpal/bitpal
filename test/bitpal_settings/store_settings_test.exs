defmodule BitPalSettings.StoreSettingsTest do
  use BitPal.DataCase, async: true
  alias BitPalSchemas.AddressKey
  alias BitPalSettings.StoreSettings

  setup _tags do
    %{store: create_store(), currency_id: unique_currency_id()}
  end

  describe "address_key" do
    setup tags = %{store: store, currency_id: currency_id} do
      if tags[:with_address] do
        key = create_address_key(%{store: store, currency_id: currency_id})
        create_address(key)
        Map.put(tags, :existing_key, key)
      else
        tags
      end
    end

    test "set xpub then fetch", %{store: store, currency_id: currency_id} do
      assert {:ok, _} = StoreSettings.set_address_key(store.id, currency_id, %{xpub: "myxpub"})
      assert StoreSettings.fetch_address_key!(store.id, currency_id).data == %{xpub: "myxpub"}
    end

    test "set viewkey then fetch", %{store: store, currency_id: currency_id} do
      assert {:ok, _} =
               StoreSettings.set_address_key(store.id, currency_id, %{
                 viewkey: "viewkey",
                 address: "some-address",
                 account: 0
               })

      assert StoreSettings.fetch_address_key!(store.id, currency_id).data == %{
               viewkey: "viewkey",
               address: "some-address",
               account: 0
             }
    end

    test "update if no addresses has been generated", %{store: store, currency_id: currency_id} do
      default_key = create_address_key(%{store: store, currency_id: currency_id})

      assert {:ok, new_key} =
               StoreSettings.set_address_key(store.id, currency_id, %{xpub: "myxpub"})

      assert new_key.id == default_key.id
      assert StoreSettings.fetch_address_key!(store.id, currency_id).data == %{xpub: "myxpub"}
    end

    @tag with_address: true
    test "insert a new xpub if address references exists", %{
      store: store,
      currency_id: currency_id,
      existing_key: existing_key
    } do
      assert {:ok, new_key} =
               StoreSettings.set_address_key(store.id, currency_id, %{xpub: "myxpub"})

      assert new_key.id != existing_key.id
      assert StoreSettings.fetch_address_key!(store.id, currency_id).data == %{xpub: "myxpub"}

      # The old one should be disconnected from the settings
      address_key = Repo.get!(AddressKey, existing_key.id)
      assert address_key.currency_settings_id == nil
    end

    @tag with_address: true
    test "Can change to the same key", %{
      store: store,
      currency_id: currency_id,
      existing_key: existing_key
    } do
      assert {:ok, address_key} =
               StoreSettings.set_address_key(store.id, currency_id, existing_key.data)

      assert address_key.id == existing_key.id
    end

    @tag with_address: true
    test "set with string keys", %{store: store, currency_id: currency_id} do
      assert {:ok, _address_key} =
               StoreSettings.set_address_key(store.id, currency_id, %{
                 "account" => "0",
                 "address" =>
                   "53SgPM7frd9M3BneMJ6VtW19dLXQVkNTdMxT6o1K9zQGMgdXwE1D62KHShZH3amVZMNVQDb9kPEJw6HuMxb96jSSBXAM5Ru",
                 "viewkey" => "1a651458fee485016e19274e3ad7cb0e7de8158e159dff9462febc91fc25410a"
               })
    end

    test "error changeset if xpub address references exists", %{
      store: store,
      currency_id: currency_id
    } do
      key_data = unique_address_key_xpub()

      create_address_key(%{store: create_store(), currency_id: currency_id, data: key_data})
      |> create_address()

      assert {:error, changeset} = StoreSettings.set_address_key(store.id, currency_id, key_data)
      assert "has already been taken" in errors_on(changeset).data
    end

    test "error changeset if viewkey address references exists", %{
      store: store,
      currency_id: currency_id
    } do
      key_data = unique_address_key_viewkey()

      create_address_key(%{store: create_store(), currency_id: currency_id, data: key_data})
      |> create_address()

      assert {:error, changeset} = StoreSettings.set_address_key(store.id, currency_id, key_data)
      assert "has already been taken" in errors_on(changeset).data
    end

    test "errors on empty", %{store: store, currency_id: currency_id} do
      assert {:error, changeset} = StoreSettings.set_address_key(store.id, currency_id, nil)

      assert "cannot be empty" in errors_on(changeset).data
    end

    test "validates BCH xpub", %{store: store} do
      assert {:ok, _} =
               StoreSettings.set_address_key(
                 store.id,
                 :BCH,
                 %{
                   xpub:
                     "xpub6C23JpFE6ABbBudoQfwMU239R5Bm6QGoigtLq1BD3cz3cC6DUTg89H3A7kf95GDzfcTis1K1m7ypGuUPmXCaCvoxDKbeNv6wRBEGEnt1NV7"
                 }
               )
    end

    test "errors on invalid BCH xpub", %{store: store} do
      assert {:error, changeset} = StoreSettings.set_address_key(store.id, :BCH, %{xpub: "xyz"})
      assert "invalid key" in errors_on(changeset).data
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

  describe "update" do
    setup tags = %{store: store, currency_id: currency_id} do
      if tags[:update] do
        {:ok, _} =
          StoreSettings.update_simple(store.id, currency_id, store_settings_update_params())
      end

      tags
    end

    test "create if not exists", %{store: store, currency_id: currency_id} do
      assert {:ok, _} =
               StoreSettings.update_simple(store.id, currency_id, store_settings_update_params())

      assert StoreSettings.get_currency_settings(store.id, currency_id) != nil
    end

    @tag update: true
    test "update existing", %{store: store, currency_id: currency_id} do
      assert StoreSettings.get_currency_settings(store.id, currency_id) != nil

      assert {:ok, settings} =
               StoreSettings.update_simple(store.id, currency_id, %{
                 "required_confirmations" => 2,
                 "double_spend_timeout" => 1337
               })

      assert settings.required_confirmations == 2
      assert settings.double_spend_timeout == 1337
    end
  end
end
