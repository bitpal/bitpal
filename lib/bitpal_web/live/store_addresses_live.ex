defmodule BitPalWeb.StoreAddressesLive do
  use BitPalWeb, :live_view
  alias BitPal.Addresses
  alias BitPal.AddressEvents
  alias BitPal.StoreEvents
  alias BitPal.Stores
  alias BitPalWeb.StoreLiveAuth

  on_mount StoreLiveAuth

  @impl true
  def mount(_params, _session, socket) do
    store = socket.assigns.store

    addresses =
      Stores.all_addresses(store.id)
      |> Repo.preload(tx_outputs: [address: :invoice])

    if connected?(socket) do
      for address <- addresses do
        AddressEvents.subscribe(address.id)
      end

      StoreEvents.subscribe(store.id)
    end

    addresses =
      Stores.all_addresses(socket.assigns.store)
      |> Repo.preload(:tx_outputs)
      |> Enum.reduce(%{}, &add_address/2)

    {:ok, assign(socket, addresses: addresses)}
  end

  @impl true
  def render(assigns) do
    render(BitPalWeb.StoreView, "addresses.html", assigns)
  end

  @impl true
  def handle_info({{:store, :invoice_created}, _}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({{:store, :address_created}, %{address_id: address_id}}, socket) do
    case Addresses.get(address_id) do
      nil ->
        {:noreply, socket}

      address ->
        AddressEvents.subscribe(address_id)
        {:noreply, update_address(address, socket)}
    end
  end

  @impl true
  def handle_info({{:tx, _}, %{id: txid}}, socket) do
    socket =
      Addresses.get_by_txid(txid)
      |> Stream.map(&Repo.preload(&1, [:address_key, :tx_outputs]))
      |> Enum.reduce(socket, fn address, socket ->
        update_address(address, socket)
      end)

    {:noreply, socket}
  end

  defp add_address(address, addresses) do
    address = Repo.preload(address, [:invoice, :address_key, :tx_outputs])
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

  @impl true
  def handle_params(_params, uri, socket) do
    {:noreply,
     assign(socket,
       uri: uri,
       breadcrumbs: Breadcrumbs.store(socket, uri, "addresses")
     )}
  end
end
