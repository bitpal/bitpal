defmodule BitPalSettings.StoreSettingsTest do
  use BitPal.DataCase, async: true
  alias BitPalSettings.StoreSettings

  setup tags do
    %{store: create_store!(tags)}
  end

  describe "xpub/2" do
    test "set and get", %{store: store} do
      # Some default value should exist

      assert is_binary(StoreSettings.get_xpub(store.id, :BCH))
      assert StoreSettings.set_xpub(store.id, :BCH, "myxpub")
      assert StoreSettings.get_xpub(store.id, :BCH) == "myxpub"

      assert StoreSettings.get_required_confirmations(store.id, :BCH) >= 0
      assert StoreSettings.set_required_confirmations(store.id, :BCH, 3)
      assert StoreSettings.get_required_confirmations(store.id, :BCH) == 3

      assert StoreSettings.get_double_spend_timeout(store.id, :BCH) > 0
      assert StoreSettings.set_double_spend_timeout(store.id, :BCH, 5_000)
      assert StoreSettings.get_double_spend_timeout(store.id, :BCH) == 5_000
    end
  end
end
