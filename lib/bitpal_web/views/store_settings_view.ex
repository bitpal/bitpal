defmodule BitPalWeb.StoreSettingsLayoutComponent do
  use BitPalWeb, :component

  def layout(assigns) do
    render(BitPalWeb.StoreSettingsView, "layout.html", assigns)
  end
end

defmodule BitPalWeb.StoreSettingsView do
  use BitPalWeb, :view

  import BitPalWeb.StoreView,
    only: [format_created_at: 1, format_last_accessed: 1, format_valid_until: 2]

  import BitPalWeb.StoreSettingsLayoutComponent

  def settings_nav_link(action, label, assigns) do
    {label, Routes.store_settings_path(assigns.socket, action, assigns.store)}
  end

  def crypto_nav_link(currency_id, assigns) do
    label = "#{Money.Currency.name!(currency_id)} (#{currency_id})"
    {label, Routes.store_settings_path(assigns.socket, :crypto, assigns.store, currency_id)}
  end
end
