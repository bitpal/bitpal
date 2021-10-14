defmodule BitPalWeb.HomeLive do
  use BitPalWeb, :live_view
  alias BitPal.Stores

  on_mount(BitPalWeb.UserLiveAuth)

  @impl true
  def mount(_params, _session, socket) do
    stores = Stores.user_stores(socket.assigns.current_user)

    {:ok, assign(socket, stores: stores)}
  end

  @impl true
  def render(assigns) do
    render(BitPalWeb.HomeView, "dashboard.html", assigns)
  end
end
