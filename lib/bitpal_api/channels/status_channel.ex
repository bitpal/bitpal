defmodule BitPalApi.StatusChannel do
  use BitPalApi, :channel
  import BitPalApi.StatusJSON
  alias BitPal.BackendManager
  alias BitPal.BackendEvents
  require Logger

  @type backend_status ::
          :ready
          | :unavailable

  @impl true
  def join("status", _payload, socket) do
    BackendEvents.subscribe_all()

    status =
      BackendManager.status_list()
      |> Map.new(fn {currency_id, _ref, status} ->
        {currency_id, transform_status(status)}
      end)

    {:ok, show_status(%{status_map: status}), assign(socket, :status, status)}
  end

  @impl true
  def handle_info({{:backend, :status}, %{status: status, currency_id: currency_id}}, socket) do
    {:noreply, update_status(currency_id, transform_status(status), socket)}
  end

  @impl true
  def handle_info({{:backend, :set_enabled}, %{currency_id: currency_id}}, socket) do
    status = BackendManager.status(currency_id)
    {:noreply, update_status(currency_id, transform_status(status), socket)}
  end

  @impl true
  def handle_info({{:backend, :info}, _}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_in(event, params, socket) do
    handle_event(event, params, socket)
  rescue
    error -> {:reply, {:error, render_error(error)}, socket}
  end

  def handle_event("backends", _params, socket) do
    {:reply, {:ok, show_status(%{status_map: socket.assigns.status})}, socket}
  end

  def handle_event(event, _params, socket) do
    Logger.error("unhandled event #{event}")
    {:noreply, socket}
  end

  defp update_status(currency_id, status, socket) do
    status_map = socket.assigns.status

    if status_map[currency_id] != status do
      broadcast!(
        socket,
        "backend_status",
        show_status(%{status: status, currency_id: currency_id})
      )

      assign(socket, :status, Map.put(status_map, currency_id, status))
    else
      socket
    end
  end

  defp transform_status(:ready), do: :ready
  defp transform_status(_), do: :unavailable
end
