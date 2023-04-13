defmodule BitPalApi.InvoiceChannel do
  use BitPalApi, :channel
  import BitPalApi.InvoiceView
  alias BitPal.Invoices
  alias BitPal.InvoiceEvents
  alias BitPalApi.InvoiceHandling
  require Logger

  @impl true
  def join("invoice:" <> invoice_id, _payload, socket) do
    with {:ok, invoice} <- authorized_invoice(invoice_id, socket.assigns),
         :ok <- InvoiceEvents.subscribe(invoice_id) do
      {:ok, %{invoice: render("show.json", invoice: invoice)},
       assign(socket, invoice_id: invoice_id)}
    else
      :unauthorized ->
        render_error(%UnauthorizedError{})

      _ ->
        render_error(%InternalServerError{})
    end
  end

  @impl true
  def join("invoices", _payload, socket) do
    {:ok, socket}
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

  defp handle_event("get", %{"id" => id}, socket) do
    invoice = InvoiceHandling.get(socket.assigns.store_id, id)
    {:reply, {:ok, render("show.json", invoice: invoice)}, socket}
  end

  defp handle_event("get", _params, socket = %{assigns: %{store_id: store_id, invoice_id: id}}) do
    invoice = InvoiceHandling.get(store_id, id)
    {:reply, {:ok, render("show.json", invoice: invoice)}, socket}
  end

  defp handle_event("get", _params, socket) do
    {:reply, render_error(%BadRequestError{}), socket}
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

  defp handle_event("create", params, socket) do
    invoice = InvoiceHandling.create(socket.assigns.store_id, params)
    {:reply, {:ok, render("show.json", invoice: invoice)}, socket}
  end

  defp handle_event("list", _params, socket) do
    invoices = InvoiceHandling.all_invoices(socket.assigns.store_id)
    {:reply, {:ok, render("index.json", invoices: invoices)}, socket}
  end

  defp authorized_invoice(invoice_id, %{store_id: store_id}) do
    case Invoices.fetch(invoice_id, store_id) do
      {:ok, invoice} ->
        {:ok, invoice}

      _ ->
        :unauthorized
    end
  end

  defp authorized_invoice(_id, _assigns) do
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
