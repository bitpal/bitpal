defmodule BitPalApi.CurrencyController do
  use BitPalApi, :controller
  alias BitPal.BackendManager
  alias BitPal.Currencies

  def action(conn, _) do
    args = [conn, conn.params, conn.assigns.current_store]
    apply(__MODULE__, action_name(conn), args)
  end

  def show(conn, %{"id" => id}, current_store) do
    with {:ok, id} <- Currencies.cast(id),
         addresses <- Currencies.addresses(id, current_store),
         invoices <- Currencies.invoices(id, current_store),
         backend_status <- BackendManager.status(id) do
      render(conn, "show.json",
        currency_id: id,
        status: backend_status,
        addresses: addresses,
        invoices: invoices
      )
    else
      _ ->
        raise NotFoundError, param: "id"
    end
  end

  def index(conn, _poroms, _current_store) do
    render(conn, "index.json", currencies: BackendManager.currency_list())
  end
end
