defmodule BitPalApi.TransactionView do
  use BitPalApi, :view
  alias BitPalSchemas.TxOutput

  def render("index.json", _) do
    %{id: "1315"}
  end

  def render("show.json", %{tx: tx = %TxOutput{}}) do
    %{
      txid: tx.txid,
      amount: Money.to_decimal(tx.amount)
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
