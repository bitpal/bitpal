defmodule BitPalApi.InvoiceChannel do
  use BitPalApi, :channel
  alias BitPal.InvoiceEvents
  alias BitPal.Stores
  alias BitPalApi.InvoiceView
  require Logger

  @impl true
  def join("invoice:" <> invoice_id, _payload, socket) do
    with :authorized <- authorized?(invoice_id, socket.assigns),
         :ok <- InvoiceEvents.subscribe(invoice_id) do
      {:ok, socket}
    else
      :unauthorized ->
        render_error(%UnauthorizedError{})

      _ ->
        render_error(%InternalServerError{})
    end
  end

  @impl true
  def handle_info(event, socket) do
    broadcast_event(event, socket)
    {:noreply, socket}
  end

  defp authorized?(invoice_id, %{store_id: store_id}) do
    if Stores.has_invoice?(store_id, invoice_id) do
      :authorized
    else
      :unauthorized
    end
  end

  defp authorized?(_payload, _assigns) do
    :unauthorized
  end

  defp broadcast_event({{:invoice, event}, data}, socket) do
    event = Atom.to_string(event)
    broadcast!(socket, event, InvoiceView.render(event <> ".json", data))
  end

  defp broadcast_event(event, _socket) do
    Logger.warn("unknown event: #{inspect(event)}")
  end
end
