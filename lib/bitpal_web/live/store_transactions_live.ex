defmodule BitPalWeb.StoreTransactionsLive do
  use BitPalWeb, :live_view
  alias BitPal.AddressEvents
  alias BitPal.StoreEvents
  alias BitPal.Stores
  alias BitPalSchemas.TxOutput
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

    txs =
      Enum.flat_map(addresses, fn address ->
        address.tx_outputs
      end)

    {:ok, assign(socket, store: store, txs: txs)}
  end

  @impl true
  def render(assigns) do
    BitPalWeb.StoreHTML.transactions(assigns)
  end

  @impl true
  def handle_params(_params, uri, socket) do
    {:noreply,
     assign(socket,
       uri: uri,
       breadcrumbs: Breadcrumbs.store(socket, uri, "transactions")
     )}
  end

  @impl true
  def handle_info({{:store, :invoice_created}, _}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({{:store, :address_created}, %{address_id: address_id}}, socket) do
    AddressEvents.subscribe(address_id)
    {:noreply, socket}
  end

  @impl true
  def handle_info({{:tx, :seen}, %{id: txid}}, socket) do
    if tx = Repo.get_by(TxOutput, txid: txid) do
      tx = Repo.preload(tx, address: :invoice)
      {:noreply, assign(socket, txs: [tx | socket.assigns.txs])}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({{:tx, _status}, %{id: txid}}, socket) do
    if tx = Repo.get_by(TxOutput, txid: txid) do
      tx = Repo.preload(tx, address: :invoice)
      {:noreply, update_tx(tx, socket)}
    else
      {:noreply, socket}
    end
  end

  defp update_tx(tx, socket) do
    txs =
      socket.assigns.txs
      |> Enum.map(fn x ->
        if x.id == tx.id do
          tx
        else
          x
        end
      end)

    assign(socket, txs: txs)
  end
end
