defmodule BitPalApi.CurrencyController do
  use BitPalApi, :controller
  alias BitPal.BackendManager
  alias BitPal.Currencies
  alias BitPal.Repo

  def show(conn, %{"id" => id}) do
    with {:ok, id} <- Currencies.cast(id),
         {:ok, currency} <- Currencies.fetch(id),
         backend_status <- BackendManager.currency_status(id) do
      currency = Repo.preload(currency, [:addresses, :invoices])
      render(conn, "show.json", currency: currency, status: backend_status)
    else
      _ ->
        raise NotFoundError, param: "id"
    end
  end

  def index(conn, _poroms) do
    render(conn, "index.json", currencies: BackendManager.currency_list())
  end
end
