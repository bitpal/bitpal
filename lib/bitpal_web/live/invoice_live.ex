defmodule BitPalWeb.InvoiceLive do
  use BitPalWeb, :live_view
  alias BitPal.Repo
  alias BitPal.InvoiceEvents
  alias BitPal.InvoiceManager
  alias BitPal.Accounts.Users
  require Logger

  on_mount(BitPalWeb.UserLiveAuth)

  @impl true
  def mount(%{"id" => invoice_id}, _session, socket) do
    if Users.invoice_access?(socket.assigns.current_user, invoice_id) do
      {:ok, assign(socket, invoice_id: invoice_id)}
    else
      {:ok, redirect(socket, to: "/")}
    end
  end

  @impl true
  def render(assigns) do
    render(BitPalWeb.InvoiceView, "show.html", assigns)
  end

  @impl true
  def handle_params(%{"id" => invoice_id}, _uri, socket) do
    InvoiceEvents.subscribe(invoice_id)
    update_invoice(invoice_id, socket)
  end

  @impl true
  def handle_info({{:invoice, _}, _data}, socket) do
    # A better solution is a CRDT, where we rebuild the invoice status
    # depending on the messages we receive. It's a bit more cumbersome,
    # but it would us allow to combine distributed data easily.
    # For now we'll just reload from the database for simplicity.
    update_invoice(socket)
  end

  defp update_invoice(socket = %{assigns: %{invoice: invoice}}) do
    update_invoice(invoice.id, socket)
  end

  defp update_invoice(invoice_id, socket) do
    case InvoiceManager.fetch_or_load_invoice(invoice_id) do
      {:ok, invoice} ->
        invoice =
          invoice
          |> Repo.preload([:tx_outputs])

        {:noreply, assign(socket, invoice: invoice)}

      _ ->
        Logger.error("Failed to update invoice: #{invoice_id}")
        {:noreply, socket}
    end
  end
end
