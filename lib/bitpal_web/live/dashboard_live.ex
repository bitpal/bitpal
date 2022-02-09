defmodule BitPalWeb.DashboardLive do
  use BitPalWeb, :live_view
  alias BitPal.BackendEvents
  alias BitPal.BackendManager
  alias BitPal.Blocks
  alias BitPal.Stores
  alias BitPal.UserEvents

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
        |> Enum.map(fn store -> {store.id, Repo.preload(store, :invoices)} end)
        |> Map.new()

      backends =
        BackendManager.status_list()
        |> Enum.map(fn {currency_id, _ref, status} ->
          BackendEvents.subscribe(currency_id)

          {currency_id,
           %{
             status: status,
             height:
               case Blocks.fetch_block_height(currency_id) do
                 {:ok, height} -> height
                 :error -> :not_found
               end
           }}
        end)
        |> Map.new()

      {:ok,
       assign(socket,
         stores: stores,
         backend_status: backends,
         store_changeset: Stores.create_changeset()
       )}
    end
  end

  @impl true
  def render(assigns) do
    render(BitPalWeb.DashboardView, "dashboard.html", assigns)
  end

  @impl true
  def handle_info({{:user, :store_created}, %{store: store}}, socket) do
    {:noreply,
     assign(socket,
       stores: Map.put(socket.assigns.stores, store.id, Repo.preload(store, :invoices))
     )}
  end

  # FIXME should update height too

  @impl true
  def handle_info({{:backend, status}, currency_id}, socket) do
    socket =
      assign(socket,
        backend_status: put_in(socket.assigns.backend_status, [currency_id, :status], status)
      )

    {:noreply, socket}
  end
end
