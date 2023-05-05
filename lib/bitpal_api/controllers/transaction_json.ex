defmodule BitPalApi.TransactionJSON do
  use BitPalApi, :json
  alias BitPalSchemas.TxOutput

  def index(%{txs: txs}) do
    Enum.map(txs, fn tx -> show(%{tx: tx}) end)
  end

  def show(%{tx: tx = %TxOutput{}}) do
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
