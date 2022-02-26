defmodule BitPalWeb.ServerSettingsLayoutComponent do
  use BitPalWeb, :component

  def layout(assigns) do
    render(BitPalWeb.ServerSettingsView, "layout.html", assigns)
  end
end

defmodule BitPalWeb.ServerSettingsView do
  use BitPalWeb, :view

  import BitPalWeb.ServerSettingsLayoutComponent

  def settings_nav_link(action, label, assigns) do
    {label, Routes.server_settings_path(assigns.socket, action)}
  end
end
