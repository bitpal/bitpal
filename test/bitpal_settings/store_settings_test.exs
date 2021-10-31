defmodule BitPalSettings.StoreSettingsTest do
  use BitPal.DataCase, async: true
  alias BitPalSettings.StoreSettings
  alias BitPal.Currencies

  setup tags do
    %{store: StoreFixtures.store_fixture()}
  end

  describe "xpub/2" do
    test "set and get", %{store: store} do
      assert is_binary(StoreSettings.get_xpub(store.id, :BCH))
      assert {:ok, _} = StoreSettings.set_xpub(store.id, :BCH, "myxpub")
      assert StoreSettings.get_xpub(store.id, :BCH) == "myxpub"

      assert StoreSettings.get_required_confirmations(store.id, :BCH) >= 0
      assert {:ok, _} = StoreSettings.set_required_confirmations(store.id, :BCH, 3)
      assert StoreSettings.get_required_confirmations(store.id, :BCH) == 3

      assert StoreSettings.get_double_spend_timeout(store.id, :BCH) > 0
      assert {:ok, _} = StoreSettings.set_double_spend_timeout(store.id, :BCH, 5_000)
      assert StoreSettings.get_double_spend_timeout(store.id, :BCH) == 5_000

      assert {:error, _} = StoreSettings.set_xpub(store.id, :XXX, "myxpub")
    end
  end
end
