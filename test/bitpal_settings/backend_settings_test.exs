defmodule BitPalSettings.BackendSettingsTest do
  use BitPal.DataCase, async: true
  alias BitPalSettings.BackendSettings

  describe "is_enabled/1" do
    setup _tags do
      %{currency_id: unique_currency_id()}
    end

    test "default to true", %{currency_id: currency_id} do
      assert BackendSettings.is_enabled(currency_id) == true
    end

    test "fetch", %{currency_id: currency_id} do
      BackendSettings.disable(currency_id)
      assert BackendSettings.is_enabled(currency_id) == false
      BackendSettings.enable(currency_id)
      assert BackendSettings.is_enabled(currency_id) == true
    end
  end

  describe "is_enabled_state/1" do
    test "adds if missing" do
      [c0, c1] = unique_currency_ids(2)
      BackendSettings.disable(c1)

      assert BackendSettings.is_enabled_state([c0, c1]) == %{c0 => true, c1 => false}
    end
  end
end
