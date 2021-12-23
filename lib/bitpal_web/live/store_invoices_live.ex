defmodule BitPalWeb.StoreInvoicesLive do
  use BitPalWeb, :live_view
  alias BitPal.Repo
  alias BitPal.InvoiceEvents
  alias BitPal.InvoiceManager
  alias BitPal.StoreEvents
  require Logger

  on_mount(BitPalWeb.UserLiveAuth)
  on_mount(BitPalWeb.StoreLiveAuth)

  @impl true
  def mount(%{"slug" => _slug}, _session, socket) do
    store = socket.assigns.store |> Repo.preload(:invoices)

    if connected?(socket) do
      for invoice <- store.invoices do
        InvoiceEvents.subscribe(invoice)
      end

      StoreEvents.subscribe(store.id)
    end

    {:ok, assign(socket, store: store)}
  end

  @impl true
  def render(assigns) do
    render(BitPalWeb.StoreView, "invoices.html", assigns)
  end

  @impl true
  def handle_info({{:store, :invoice_created}, %{invoice_id: invoice_id}}, socket) do
    InvoiceEvents.subscribe(invoice_id)
    update_invoice(invoice_id, socket)
  end

  @impl true
  def handle_info({{:invoice, _}, %{id: invoice_id}}, socket) do
    # A better solution is a CRDT, where we rebuild the invoice status
    # depending on the messages we receive. It's a bit more cumbersome,
    # but it would us allow to combine distributed data easily.
    # For now we'll just reload from the database for simplicity.
    update_invoice(invoice_id, socket)
  end

  @impl true
  def handle_params(_params, uri, socket) do
    {:noreply, assign(socket, uri: uri)}
  end

  defp update_invoice(invoice_id, socket) do
    case InvoiceManager.fetch_or_load_invoice(invoice_id) do
      {:ok, invoice} ->
        store = socket.assigns.store

        # FIXME should do this in place
        updated_invoices =
          Enum.reject(store.invoices, fn x ->
            x.id == invoice.id
          end) ++
            [invoice]

        {:noreply, assign(socket, store: %{store | invoices: updated_invoices})}

      _ ->
        Logger.error("Failed to update invoice: #{invoice_id}")
        {:noreply, socket}
    end
  end
end
