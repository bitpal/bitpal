defmodule BitPalApi.TransactionView do
  use BitPalApi, :view
  alias BitPalSchemas.TxOutput

  def render("index.json", %{txs: txs}) do
    Enum.map(txs, fn tx -> render("show.json", tx: tx) end)
  end

  def render("show.json", %{tx: tx = %TxOutput{}}) do
    %{
      txid: tx.txid,
      amount: Money.to_decimal(tx.amount),
      address: tx.address_id
    }
    |> then(fn res ->
      # Don't add confirmed or double spend info unless they're relevant.
      cond do
        tx.confirmed_height != nil ->
          Map.put(res, :confirmed_height, tx.confirmed_height)

        tx.double_spent ->
          Map.put(res, :double_spent, tx.double_spent)

        true ->
          res
      end
    end)
  end
end
