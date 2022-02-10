defmodule BitPalWeb.BackendLive do
  use BitPalWeb, :live_view
  alias BitPal.Backend
  alias BitPal.BackendEvents
  alias BitPal.BackendSupervisor
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
          |> assign_info(BackendSupervisor.fetch_backend(currency_id))

        if connected?(socket) do
          BackendEvents.subscribe(currency_id)
          Process.send_after(self(), :poll, 1_000)
        end

        {:noreply, socket}

      :error ->
        {:noreply, push_redirect(socket, to: Routes.dashboard_path(socket, :show))}
    end
  end

  defp assign_info(socket, {:error, :not_found}) do
    assign(socket, status: :not_found)
  end

  defp assign_info(socket, {:ok, ref = {_pid, module}}) do
    assign(socket,
      plugin: module,
      status: Backend.status(ref),
      info: Backend.info(ref)
    )
  end

  @impl true
  def render(assigns) do
    render(BitPalWeb.BackendView, "show.html", assigns)
  end

  @impl true
  def handle_info(:poll, socket) do
    # FIXME Should also update info + status (and plugin if we don't have that)
    BackendSupervisor.poll_currency_info(socket.assigns.currency_id)
    Process.send_after(self(), :poll, 3_000)
    {:noreply, assign_info(socket, BackendSupervisor.fetch_backend(socket.assigns.currency_id))}
  end

  def handle_info({{:backend, :status}, %{status: status}}, socket) do
    {:noreply, assign(socket, status: status)}
  end

  def handle_info({{:backend, :info}, %{info: info}}, socket) do
    {:noreply, assign(socket, info: info)}
  end

  # FIXME
  # 2. Should be able to manually restart it (or it's done automatically)
end
