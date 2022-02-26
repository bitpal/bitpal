defmodule BitPalWeb.BackendLive do
  use BitPalWeb, :live_view
  alias BitPal.Backend
  alias BitPal.BackendEvents
  alias BitPal.BackendManager
  alias BitPal.Currencies

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"crypto" => crypto}, uri, socket) do
    case Currencies.cast(crypto) do
      {:ok, currency_id} ->
        socket =
          socket
          |> assign(
            currency_id: currency_id,
            breadcrumbs: Breadcrumbs.backend(socket, uri, currency_id)
          )
          |> assign_status()
          |> assign_info()

        if connected?(socket) do
          BackendEvents.subscribe(currency_id)
          Process.send_after(self(), :poll, 1_000)
        end

        {:noreply, socket}

      :error ->
        {:noreply, push_redirect(socket, to: Routes.dashboard_path(socket, :show))}
    end
  end

  defp assign_status(socket) do
    assign(socket, status: BackendManager.status(socket.assigns.currency_id))
  end

  defp assign_info(socket) do
    update_info(socket, BackendManager.fetch_backend(socket.assigns.currency_id))
  end

  defp update_info(socket, {:error, _}) do
    assign(socket, info: nil)
  end

  defp update_info(socket, {:ok, ref = {_pid, module}}) do
    assign(socket,
      plugin: module,
      info: Backend.info(ref)
    )
  end

  @impl true
  def render(assigns) do
    render(BitPalWeb.BackendView, "show.html", assigns)
  end

  @impl true
  def handle_info(:poll, socket) do
    ref = BackendManager.fetch_backend(socket.assigns.currency_id)

    socket =
      socket
      |> assign_status()
      |> update_info(ref)

    case ref do
      {:ok, {pid, module}} ->
        module.poll_info(pid)

      _ ->
        nil
    end

    Process.send_after(self(), :poll, 3_000)

    {:noreply, socket}
  end

  def handle_info({{:backend, :status}, %{status: status}}, socket) do
    {:noreply, assign(socket, status: status)}
  end

  def handle_info({{:backend, :info}, %{info: info}}, socket) do
    {:noreply, assign(socket, info: info)}
  end
end
