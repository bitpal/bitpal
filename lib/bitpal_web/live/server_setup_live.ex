defmodule BitPalWeb.ServerSetupLive do
  use BitPalWeb, :live_view
  alias BitPal.ServerSetup
  alias BitPal.Stores

  @impl true
  def mount(_params, _session, socket) do
    {:ok, set_state(socket, ServerSetup.setup_state())}
  end

  @impl true
  def render(assigns) do
    template = Atom.to_string(assigns.state) <> ".html"
    render_existing(BitPalWeb.ServerSetupView, template, assigns)
  end

  @impl true
  def handle_event("skip", _params, socket) do
    {:noreply, set_state(socket, ServerSetup.next_state())}
  end

  @impl true
  def handle_event("create_store", %{"store" => params}, socket) do
    changeset = Stores.create_changeset(socket.assigns.current_user, params)

    case Stores.create(changeset) do
      {:ok, _store} ->
        {:noreply, set_state(socket, ServerSetup.next_state())}

      {:error, changeset} ->
        {:noreply, assign(socket, store_changeset: changeset)}
    end
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
