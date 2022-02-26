defmodule BitPalWeb.ServerSetupLive do
  use BitPalWeb, :live_view
  import BitPalWeb.ServerSetup, only: [server_setup_name: 1]
  alias BitPal.ServerSetup
  alias BitPal.Stores

  @impl true
  def mount(_params, session, socket) do
    server_name = server_setup_name(session)

    socket =
      socket
      |> assign(server_setup_name: server_name)
      |> set_state(ServerSetup.current_state(server_name))

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    template = Atom.to_string(assigns.state) <> ".html"
    render(BitPalWeb.ServerSetupView, template, assigns)
  end

  @impl true
  def handle_event("skip", _params, socket) do
    {:noreply, set_next(socket)}
  end

  @impl true
  def handle_event("create_store", %{"store" => params}, socket) do
    changeset = Stores.create_changeset(socket.assigns.current_user, params)

    case Stores.create(changeset) do
      {:ok, _store} ->
        {:noreply, set_next(socket)}

      {:error, changeset} ->
        {:noreply, assign(socket, store_changeset: changeset)}
    end
  end

  defp set_next(socket) do
    state = ServerSetup.set_next(socket.assigns.server_setup_name)
    set_state(socket, state)
  end

  defp set_state(socket, state) do
    socket
    |> assign(state: state)
    |> add_state_assigns()
  end

  defp add_state_assigns(socket) do
    case socket.assigns.state do
      :create_store ->
        assign(socket, store_changeset: Stores.create_changeset())

      _ ->
        socket
    end
  end
end
