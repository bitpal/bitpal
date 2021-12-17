defmodule BitPalWeb.StoreTransactionsLive do
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
    store =
      socket.assigns.store
      |> Repo.preload(invoices: [address: [:invoice, tx_outputs: [:address, :invoice]]])

    if connected?(socket) do
      # for invoice <- store.invoices do
      #   InvoiceEvents.subscribe(invoice)
      # end
      #
      # StoreEvents.subscribe(store.id)
    end

    txs =
      store.invoices
      |> Stream.map(fn invoice -> invoice.address end)
      |> Stream.filter(fn address -> address end)
      |> Enum.flat_map(fn address -> address.tx_outputs end)

    {:ok, assign(socket, store: store, txs: txs)}
  end

  @impl true
  def render(assigns) do
    # Txid
    # Amount
    # Address id(s)
    # Currency
    # Invoice
    # Confirmed height
    # Double spent?
    render(BitPalWeb.StoreView, "transactions.html", assigns)
  end

  @impl true
  def handle_params(_params, uri, socket) do
    {:noreply, assign(socket, uri: uri)}
  end
end
