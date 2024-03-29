defmodule BitPalWeb.DashboardLive do
  use BitPalWeb, :live_view
  import BitPalWeb.BackendComponents, only: [format_backend_status: 1]
  import BitPalWeb.DashboardComponents
  alias BitPal.BackendEvents
  alias BitPal.BackendManager
  alias BitPal.Currencies
  alias BitPal.Stores
  alias BitPal.UserEvents
  alias BitPalSettings.BackendSettings

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

          {currency_id, %{status: status, is_enabled: BackendSettings.is_enabled(currency_id)}}
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
  def handle_info({{:user, :store_created}, %{store: store}}, socket) do
    {:noreply,
     assign(socket,
       stores: Map.put(socket.assigns.stores, store.id, Repo.preload(store, :invoices))
     )}
  end

  @impl true
  def handle_info({{:backend, :status}, %{status: status, currency_id: currency_id}}, socket) do
    socket =
      assign(socket,
        backend_status: put_in(socket.assigns.backend_status, [currency_id, :status], status)
      )

    {:noreply, socket}
  end

  @impl true
  def handle_info(
        {{:backend, :set_enabled}, %{is_enabled: is_enabled, currency_id: currency_id}},
        socket
      ) do
    socket =
      assign(socket,
        backend_status:
          put_in(socket.assigns.backend_status, [currency_id, :is_enabled], is_enabled)
      )

    {:noreply, socket}
  end

  @impl true
  def handle_info(_, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("enable", %{"id" => crypto}, socket) do
    case Currencies.cast(crypto) do
      {:ok, currency_id} ->
        BackendManager.enable_backend(currency_id)
        {:noreply, socket}

      :error ->
        Logger.error("Invalid crypto: #{inspect(crypto)}")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("disable", %{"id" => crypto}, socket) do
    case Currencies.cast(crypto) do
      {:ok, currency_id} ->
        BackendManager.disable_backend(currency_id)
        {:noreply, socket}

      :error ->
        Logger.error("Invalid crypto: #{inspect(crypto)}")
        {:noreply, socket}
    end
  end
end
