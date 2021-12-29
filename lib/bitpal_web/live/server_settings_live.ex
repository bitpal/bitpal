defmodule BitPalWeb.ServerSettingsLive do
  use BitPalWeb, :live_view
  require Logger

  on_mount(BitPalWeb.UserLiveAuth)

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    render(BitPalWeb.ServerSettingsLive, "show.html", assigns)
  end
end
