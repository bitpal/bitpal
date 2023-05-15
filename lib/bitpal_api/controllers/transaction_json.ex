defmodule BitPalApi.TransactionJSON do
  use BitPalApi, :json

  def index(%{txs: txs}) do
    Enum.map(txs, fn tx_info -> show(tx_info) end)
  end

  def show(%{
        txid: txid,
        height: height,
        failed: failed,
        double_spent: double_spent,
        amount: amount,
        address_id: address_id
      }) do
    %{
      txid: txid,
      outputDisplay: money_to_string(amount),
      outputSubAmount: amount.amount,
      address: address_id,
      double_spent: double_spent,
      failed: failed
    }
    |> put_unless(:height, height, 0)
  end
end
