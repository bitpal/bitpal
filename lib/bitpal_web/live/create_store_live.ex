defmodule BitPalWeb.CreateStoreLive do
  use BitPalWeb, :live_view
  alias BitPal.Stores

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       store_changeset: Stores.create_changeset()
     )}
  end

  @impl true
  def render(assigns) do
    render(BitPalWeb.StoreView, "create.html", assigns)
  end

  @impl true
  def handle_event("create_store", %{"store" => params}, socket) do
    changeset = Stores.create_changeset(socket.assigns.current_user, params)

    case Stores.create(changeset) do
      {:ok, store} ->
        {:noreply, push_redirect(socket, to: Routes.store_settings_path(socket, :general, store))}

      {:error, changeset} ->
        {:noreply, assign(socket, store_changeset: changeset)}
    end
  end
end
