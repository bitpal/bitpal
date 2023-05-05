defmodule BitPalWeb.ServerSettingsLive do
  use BitPalWeb, :live_view
  require Logger

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    apply(BitPalWeb.ServerSettingsView, assigns.live_action, [assigns])
  end

  @impl true
  def handle_params(_params, uri, socket) do
    if socket.assigns[:live_action] == :redirect do
      {:noreply,
       push_patch(
         socket,
         to: ~p"/server/settings/backends",
         replace: true
       )}
    else
      {:noreply, init_assigns(socket, uri)}
    end
  end

  defp init_assigns(socket, uri) do
    socket
    |> assign(uri: uri)
    |> assign_breadcrumbs()
    |> assign_live_action(socket.assigns.live_action)
  end

  defp assign_breadcrumbs(socket) do
    socket
    |> assign(breadcrumbs: Breadcrumbs.server_settings(socket, socket.assigns.uri))
  end

  defp assign_live_action(socket, _) do
    socket
  end
end
