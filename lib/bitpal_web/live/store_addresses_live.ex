defmodule BitPalWeb.StoreAddressesLive do
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
    store = socket.assigns.store

    if connected?(socket) do
      # FIXME needs events whenever an address is created
      # Can check invoice created and invoice finalized I guess?
      # for invoice <- store.invoices do
      #   InvoiceEvents.subscribe(invoice)
      # end

      StoreEvents.subscribe(store.id)
    end

    {:ok, assign(socket, store: store, addresses: [])}
  end

  @impl true
  def render(assigns) do
    render(BitPalWeb.StoreView, "addresses.html", assigns)
  end

  # @impl true
  # def handle_info({:invoice_created, %{invoice_id: invoice_id}}, socket) do
  #   InvoiceEvents.subscribe(invoice_id)
  #   update_invoice(invoice_id, socket)
  # end
  #
  # @impl true
  # def handle_info({event, %{id: invoice_id}}, socket) do
  #   # A better solution is a CRDT, where we rebuild the invoice status
  #   # depending on the messages we receive. It's a bit more cumbersome,
  #   # but it would us allow to combine distributed data easily.
  #   # For now we'll just reload from the database for simplicity.
  #   case Atom.to_string(event) do
  #     "invoice_" <> _ ->
  #       update_invoice(invoice_id, socket)
  #
  #     _ ->
  #       {:noreply, socket}
  #   end
  # end

  @impl true
  def handle_params(_params, uri, socket) do
    {:noreply, assign(socket, uri: uri)}
  end
end
