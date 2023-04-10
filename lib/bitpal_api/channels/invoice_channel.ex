defmodule BitPalApi.InvoiceChannel do
  use BitPalApi, :channel
  import BitPalApi.InvoiceView
  alias BitPal.InvoiceEvents
  alias BitPal.Stores
  alias BitPalApi.InvoiceHandling
  require Logger

  @impl true
  def join("invoice:" <> invoice_id, _payload, socket) do
    with :authorized <- authorized?(invoice_id, socket.assigns),
         :ok <- InvoiceEvents.subscribe(invoice_id) do
      {:ok, assign(socket, invoice_id: invoice_id)}
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

  @impl true
  def handle_in(event, params, socket) do
    handle_event(event, params, socket)
  rescue
    error -> {:reply, render_error(error), socket}
  end

  defp handle_event("get", _params, socket) do
    invoice = InvoiceHandling.get(socket.assigns.store_id, socket.assigns.invoice_id)
    {:reply, {:ok, render("show.json", invoice: invoice)}, socket}
  end

  defp handle_event("update", params, socket) do
    invoice = InvoiceHandling.update(socket.assigns.store_id, socket.assigns.invoice_id, params)
    {:reply, {:ok, render("show.json", invoice: invoice)}, socket}
  end

  # These messages already produces a broadcast over the channel.
  # So instead of creating duplicate messages, just reply with :ok and let the bradcast
  # handle the reply data.

  defp handle_event("delete", _params, socket) do
    InvoiceHandling.delete(socket.assigns.store_id, socket.assigns.invoice_id)
    {:reply, :ok, socket}
  end

  defp handle_event("finalize", _params, socket) do
    InvoiceHandling.finalize(socket.assigns.store_id, socket.assigns.invoice_id)
    {:reply, :ok, socket}
  end

  defp handle_event("pay", _params, socket) do
    InvoiceHandling.pay(socket.assigns.store_id, socket.assigns.invoice_id)
    {:reply, :ok, socket}
  end

  defp handle_event("void", _params, socket) do
    InvoiceHandling.void(socket.assigns.store_id, socket.assigns.invoice_id)
    {:reply, :ok, socket}
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
