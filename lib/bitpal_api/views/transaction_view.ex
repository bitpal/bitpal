defmodule BitPalApi.TransactionView do
  use BitPalApi, :view
  alias BitPalSchemas.TxOutput

  def render("index.json", %{txs: txs}) do
    Enum.map(txs, fn tx -> render("show.json", tx: tx) end)
  end

  def render("show.json", %{tx: tx = %TxOutput{}}) do
    %{
      txid: tx.txid,
      outputDisplay: money_to_string(tx.amount),
      outputSubAmount: tx.amount.amount,
      address: tx.address_id
    }
    |> put_unless_nil(:confirmed_height, tx.confirmed_height)
    |> put_unless_nil(:double_spent, tx.double_spent)
  end
end
