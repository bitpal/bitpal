defmodule BitPalWeb.StoreTransactionsLive do
  use BitPalWeb, :live_view
  alias BitPal.AddressEvents
  alias BitPal.Repo
  alias BitPal.StoreEvents
  alias BitPal.Stores
  alias BitPalSchemas.TxOutput
  require Logger

  on_mount(BitPalWeb.UserLiveAuth)
  on_mount(BitPalWeb.StoreLiveAuth)

  @impl true
  def mount(%{"slug" => _slug}, _session, socket) do
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

    # FIXME need more info to sort on
    txs =
      Enum.flat_map(addresses, fn address ->
        address.tx_outputs
      end)

    {:ok, assign(socket, store: store, txs: txs)}
  end

  @impl true
  def render(assigns) do
    # Txid
    # Amount
    # Address id(s)
    # Currency
    # Invoice link
    # Confirmed height
    # Double spent?
    render(BitPalWeb.StoreView, "transactions.html", assigns)
  end

  @impl true
  def handle_params(_params, uri, socket) do
    {:noreply, assign(socket, uri: uri)}
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
  def handle_info({{:tx, _}, %{id: txid}}, socket) do
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
