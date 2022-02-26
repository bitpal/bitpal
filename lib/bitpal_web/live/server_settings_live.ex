defmodule BitPalWeb.ServerSettingsLive do
  use BitPalWeb, :live_view
  require Logger

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    template = Atom.to_string(assigns.live_action) <> ".html"
    render(BitPalWeb.ServerSettingsView, template, assigns)
  end

  @impl true
  def handle_params(_params, uri, socket) do
    if socket.assigns[:live_action] == :redirect do
      {:noreply,
       push_patch(
         socket,
         to: Routes.server_settings_path(socket, :backends),
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
