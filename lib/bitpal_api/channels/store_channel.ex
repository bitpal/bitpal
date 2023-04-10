defmodule BitPalApi.StoreChannel do
  use BitPalApi, :channel
  import BitPalApi.InvoiceView
  alias BitPalApi.InvoiceHandling
  require Logger

  @impl true
  def join("store:" <> store_id, _payload, socket) do
    case authorized?(store_id, socket.assigns) do
      :authorized ->
        {:ok, socket}

      :unauthorized ->
        render_error(%UnauthorizedError{})
    end
  end

  @impl true
  def handle_in(event, params, socket) do
    handle_event(event, params, socket)
  rescue
    error -> {:reply, render_error(error), socket}
  end

  defp handle_event("create_invoice", params, socket) do
    invoice = InvoiceHandling.create(socket.assigns.store_id, params)
    {:reply, {:ok, render("show.json", invoice: invoice)}, socket}
  end

  defp handle_event("get_invoice", %{"id" => id}, socket) do
    invoice = InvoiceHandling.get(socket.assigns.store_id, id)
    {:reply, {:ok, render("show.json", invoice: invoice)}, socket}
  end

  defp handle_event("list_invoices", _params, socket) do
    invoices = InvoiceHandling.all_invoices(socket.assigns.store_id)
    {:reply, {:ok, render("index.json", invoices: invoices)}, socket}
  end

  defp authorized?(joined_id, %{store_id: token_id}) do
    if joined_id == Integer.to_string(token_id) do
      :authorized
    else
      :unauthorized
    end
  end

  defp authorized?(_payload, _assigns) do
    :unauthorized
  end
end
