defmodule BitPalApi.InvoiceChannel do
  use BitPalApi, :channel
  alias BitPal.InvoiceEvents
  alias BitPalApi.InvoiceView
  require Logger

  @impl true
  def join("invoice:" <> invoice_id, payload, socket) do
    with :authorized <- authorized?(payload),
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
  def handle_info({event, data}, socket) do
    broadcast_event(Atom.to_string(event), data, socket)
    {:noreply, socket}
  end

  defp authorized?(_payload) do
    :authorized
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
