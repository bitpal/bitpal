defmodule BitPalApi.TransactionController do
  use BitPalApi, :controller
  alias BitPal.Transactions

  def index(conn, _params) do
    render(conn, "index.json", txs: Transactions.all())
  end

  def show(conn, %{"txid" => txid}) do
    case Transactions.fetch(txid) do
      {:ok, tx} ->
        render(conn, "show.json", tx: tx)

      :error ->
        raise NotFoundError, param: "txid"
    end
  end
end
