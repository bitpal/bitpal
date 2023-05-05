defmodule BitPalWeb.InvoiceLiveAuth do
  use BitPalWeb, :live_auth
  alias BitPal.Accounts.Users
  alias BitPal.Stores

  def on_mount(:default, %{"id" => invoice_id}, _session, socket) do
    cond do
      socket.assigns[:invoice_id] ->
        {:cont, socket}

      Users.invoice_access?(socket.assigns.current_user, invoice_id) ->
        {:ok, store} = Stores.fetch_by_invoice(invoice_id)
        {:cont, assign(socket, invoice_id: invoice_id, store: store)}

      true ->
        {:halt, redirect(socket, to: "/")}
    end
  end
end
