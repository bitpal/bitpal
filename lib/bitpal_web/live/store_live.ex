defmodule BitPalWeb.StoreLive do
  use BitPalWeb, :live_view
  alias BitPal.Repo
  alias BitPal.InvoiceEvents
  alias BitPal.InvoiceManager
  alias BitPal.StoreEvents
  alias BitPal.Accounts.Users
  require Logger

  on_mount(BitPalWeb.UserLiveAuth)

  @impl true
  def mount(%{"id" => store_id}, _session, socket) do
    {:ok, assign(socket, store_id: store_id)}
  end

  @impl true
  def render(assigns) do
    render(BitPalWeb.StoreView, "show.html", assigns)
  end

  @impl true
  def handle_params(%{"id" => store_id}, _uri, socket) do
    case Users.fetch_store(socket.assigns.current_user, store_id) do
      {:ok, store} ->
        store =
          store
          |> Repo.preload([:invoices])

        for invoice <- store.invoices do
          InvoiceEvents.subscribe(invoice)
        end

        StoreEvents.subscribe(store.id)

        {:noreply, assign(socket, store: store)}

      _ ->
        {:noreply, redirect(socket, to: "/")}
    end
  end

  @impl true
  def handle_info({:invoice_created, %{invoice_id: invoice_id}}, socket) do
    InvoiceEvents.subscribe(invoice_id)
    update_invoice(invoice_id, socket)
  end

  @impl true
  def handle_info({event, %{id: invoice_id}}, socket) do
    # A better solution is a CRDT, where we rebuild the invoice status
    # depending on the messages we receive. It's a bit more cumbersome,
    # but it would us allow to combine distributed data easily.
    # For now we'll just reload from the database for simplicity.
    case Atom.to_string(event) do
      "invoice_" <> _ ->
        update_invoice(invoice_id, socket)

      _ ->
        {:noreply, socket}
    end
  end

  defp update_invoice(invoice_id, socket) do
    case InvoiceManager.fetch_or_load_invoice(invoice_id) do
      {:ok, invoice} ->
        store = socket.assigns.store

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
