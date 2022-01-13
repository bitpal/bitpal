defmodule BitPalWeb.HomeLive do
  use BitPalWeb, :live_view
  alias BitPal.Stores
  alias BitPal.BackendManager
  alias BitPal.UserEvents
  alias BitPal.BackendEvents

  on_mount(BitPalWeb.UserLiveAuth)

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      UserEvents.subscribe(socket.assigns.current_user)
    end

    if socket.assigns[:stores] do
      {:ok, socket}
    else
      stores =
        socket.assigns.current_user
        |> Stores.user_stores()
        |> Enum.map(fn store -> {store.id, store} end)
        |> Map.new()

      backends =
        BackendManager.status_list()
        |> Enum.map(fn {currency_id, _ref, status} ->
          BackendEvents.subscribe(currency_id)
          {currency_id, status}
        end)
        |> Map.new()

      {:ok,
       assign(socket,
         stores: stores,
         backend_status: backends
       )}
    end
  end

  @impl true
  def render(assigns) do
    render(BitPalWeb.HomeView, "dashboard.html", assigns)
  end

  @impl true
  def handle_info({{:user, :store_created}, %{store: store}}, socket) do
    {:noreply, assign(socket, stores: Map.put(socket.assigns.stores, store.id, store))}
  end

  @impl true
  def handle_info({{:backend, status}, currency_id}, socket) do
    {:noreply,
     assign(socket, backend_status: Map.put(socket.assigns.backend_status, currency_id, status))}
  end
end
