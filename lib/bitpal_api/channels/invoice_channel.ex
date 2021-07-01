defmodule BitPalApi.InvoiceChannel do
  use BitPalApi, :channel
  alias BitPal.InvoiceEvents
  alias BitPalApi.InvoiceView
  require Logger

  @impl true
  def join("invoice:" <> invoice_id, payload, socket) do
    if authorized?(payload) do
      :ok = InvoiceEvents.subscribe(invoice_id)
      {:ok, socket}
    else
      render_error(:unauthorized)
    end
  end

  @impl true
  def handle_info({event, data}, socket) do
    broadcast_event(Atom.to_string(event), data, socket)
    {:noreply, socket}
  end

  defp authorized?(_payload) do
    true
  end

  defp broadcast_event("invoice_" <> event, data, socket) do
    broadcast!(
      socket,
      event,
      InvoiceView.render(event <> ".json", data)
    )
  end

  defp broadcast_event(event, _data, _socket) do
    Logger.warn("unknown event: #{event}")
  end
end
