defmodule BitPalApi.TransactionController do
  use BitPalApi, :controller
  alias BitPal.Stores
  alias BitPal.Transactions

  def action(conn, _) do
    args = [conn, conn.params, conn.assigns.current_store]
    apply(__MODULE__, action_name(conn), args)
  end

  def index(conn, _params, current_store) do
    render(conn, :index, txs: Stores.tx_outputs(current_store))
  end

  def show(conn, %{"txid" => txid}, current_store) do
    case Transactions.fetch(txid, current_store) do
      {:ok, tx} ->
        render(conn, :show, tx: tx)

      _ ->
        raise NotFoundError, param: "txid"
    end
  end
end
