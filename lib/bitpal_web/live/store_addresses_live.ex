defmodule BitPalWeb.StoreAddressesLive do
  use BitPalWeb, :live_view
  alias BitPal.InvoiceEvents
  alias BitPal.InvoiceManager
  alias BitPal.Repo
  alias BitPal.StoreEvents
  alias BitPal.Stores
  alias BitPalSchemas.Invoice
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

      StoreEvents.subscribe(store.id)
    end

    {:ok, fetch_addresses(socket)}
  end

  @impl true
  def render(assigns) do
    render(BitPalWeb.StoreView, "addresses.html", assigns)
  end

  @impl true
  def handle_info({{:store, :invoice_created}, %{invoice_id: invoice_id}}, socket) do
    {:ok, invoice} = InvoiceManager.fetch_or_load_invoice(invoice_id)

    InvoiceEvents.subscribe(invoice_id)

    if invoice.address_id do
      {:noreply, update_address(invoice.address, socket)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({{:store, :address_created}, _}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({{:invoice, _}, args}, socket) do
    invoice =
      get_invoice(args)
      |> Repo.preload(:address)

    {:noreply, update_address(invoice.address, socket)}
  end

  defp fetch_addresses(socket) do
    if socket.assigns[:addresses] do
      socket
    else
      addresses =
        Stores.all_addresses(socket.assigns.store)
        |> Repo.preload(:tx_outputs)
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

  defp get_invoice(invoice = %Invoice{}) do
    invoice
  end

  defp get_invoice(%{id: id}) do
    {:ok, invoice} = InvoiceManager.fetch_or_load_invoice(id)
    invoice
  end

  @impl true
  def handle_params(_params, uri, socket) do
    {:noreply, assign(socket, uri: uri)}
  end
end
