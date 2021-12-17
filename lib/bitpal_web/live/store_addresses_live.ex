defmodule BitPalWeb.StoreAddressesLive do
  use BitPalWeb, :live_view
  alias BitPal.Repo
  alias BitPal.Stores
  alias BitPal.InvoiceEvents
  alias BitPal.AddressEvents
  alias BitPal.InvoiceManager
  alias BitPal.StoreEvents
  alias BitPal.Invoices
  require Logger

  on_mount(BitPalWeb.UserLiveAuth)
  on_mount(BitPalWeb.StoreLiveAuth)

  @impl true
  def mount(%{"slug" => _slug}, _session, socket) do
    if connected?(socket) do
      store = socket.assigns.store |> Repo.preload(:invoices)

      for invoice <- store.invoices do
        InvoiceEvents.subscribe(invoice)
      end

      for address <- Stores.all_addresses(store.id) do
        AddressEvents.subscribe(address.id)
      end

      StoreEvents.subscribe(store.id)
    end

    {:ok, fetch_addresses(socket)}
  end

  @impl true
  def render(assigns) do
    render(BitPalWeb.StoreView, "addresses.html", assigns)
  end

  @impl true
  def handle_info({:invoice_created, %{invoice_id: invoice_id}}, socket) do
    IO.puts("invoice created #{invoice_id}")
    {:ok, invoice} = InvoiceManager.fetch_or_load_invoice(invoice_id)

    InvoiceEvents.subscribe(invoice_id)

    if invoice.address_id do
      {:noreply, update_address(invoice.address, socket)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:invoice_finalized, invoice}, socket) do
    IO.puts("invoice finalized #{invoice.address_id}")
    # AddressEvents.subscribe(invoice.address_id)
    # InvoiceEvents.unsubscribe(invoice)
    {:noreply, update_address(invoice.address, socket)}
  end

  @impl true
  def handle_info(event, socket) do
    IO.inspect(event)
    {:noreply, socket}
  end

  defp fetch_addresses(socket) do
    if socket.assigns[:addresses] do
      socket
    else
      addresses =
        Stores.all_addresses(socket.assigns.store)
        |> Enum.reduce(%{}, &add_address/2)

      assign(socket, addresses: addresses)
    end
  end

  defp add_address(address, addresses) do
    address = Repo.preload(address, [:invoice, :address_key])
    key = address.address_key.data

    Map.put(
      addresses,
      key,
      case Map.get(addresses, key) do
        nil -> [address]
        addresses -> [address | addresses]
      end
    )
  end

  defp update_address(address, socket) do
    assign(socket, addresses: add_address(address, socket.assigns.addresses))
  end

  # @impl true
  # def handle_info({:invoice_created, %{invoice_id: invoice_id}}, socket) do
  #   # InvoiceEvents.subscribe(invoice_id)
  #   # update_invoice(invoice_id, socket)
  # end
  #
  # @impl true
  # def handle_info({:invoice_finalized, invoice}, socket) do
  #   # InvoiceEvents.subscribe(invoice_id)
  #   # update_invoice(invoice_id, socket)
  # end

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
