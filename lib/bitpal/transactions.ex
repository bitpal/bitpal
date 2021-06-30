defmodule BitPal.Transactions do
  import Ecto.Query, only: [from: 2]
  alias BitPal.AddressEvents
  alias BitPal.Blocks
  alias BitPal.Repo
  alias BitPalSchemas.Address
  alias BitPalSchemas.TxOutput
  require Logger

  @type height :: non_neg_integer
  @type confirmations :: non_neg_integer
  @type outputs :: [{Address.id(), Money.t()}]

  @spec num_confirmations!(TxOutput.t()) :: confirmations
  def num_confirmations!(tx = %TxOutput{currency: currency}) do
    num_confirmations(tx, Blocks.fetch_block_height!(currency))
  end

  @spec num_confirmations(TxOutput.t(), height) :: confirmations
  def num_confirmations(%TxOutput{confirmed_height: tx_height}, block_height) do
    calc_confirmations(tx_height, block_height)
  end

  @spec calc_confirmations(height, height) :: confirmations
  def calc_confirmations(tx_height, block_height)
      when is_integer(tx_height) and tx_height >= 0 and is_integer(block_height) and
             block_height >= 0 do
    max(0, block_height - tx_height + 1)
  end

  def calc_confirmations(_, _) do
    0
  end

  @spec seen(TxOutput.txid(), outputs) :: :ok | :error
  def seen(txid, outputs) do
    insert(txid, outputs, {:tx_seen, txid})
  end

  @spec confirmed(TxOutput.txid(), outputs, height) :: :ok | :error
  def confirmed(txid, outputs, height) do
    update(txid, outputs, {:tx_confirmed, txid, height}, confirmed_height: height)
  end

  @spec double_spent(TxOutput.txid(), outputs) :: :ok | :error
  def double_spent(txid, outputs) do
    update(txid, outputs, {:tx_double_spent, txid}, double_spent: true)
  end

  @spec reversed(TxOutput.txid(), outputs) :: :ok | :error
  def reversed(txid, outputs) do
    update(txid, outputs, {:tx_reversed, txid}, confirmed_height: nil)
  end

  @spec update(TxOutput.txid(), outputs, AddressEvents.msg(), keyword) :: :ok | :error
  defp update(txid, outputs, msg, changes) do
    output_count = Enum.count(outputs)

    case Repo.update_all(from(t in TxOutput, where: t.txid == ^txid, update: [set: ^changes]), []) do
      {^output_count, _} ->
        broadcast(outputs, msg)

      _ ->
        insert(txid, outputs, msg, changes)
    end
  end

  @spec insert(TxOutput.txid(), outputs, AddressEvents.msg(), keyword) :: :ok | :error
  defp insert(txid, outputs, msg, extra \\ []) do
    output_count = Enum.count(outputs)

    case Repo.insert_all(
           TxOutput,
           Enum.map(outputs, fn {address_id, amount} ->
             %{
               txid: txid,
               address_id: address_id,
               amount: amount
             }
             |> Map.merge(Enum.into(extra, %{}))
           end)
         ) do
      {^output_count, _} ->
        broadcast(outputs, msg)

      err ->
        Logger.error("Failed to insert tx #{txid}: #{inspect(err)}")
        :error
    end
  end

  @spec broadcast(outputs, AddressEvents.msg()) :: :ok
  defp broadcast(outputs, msg) do
    outputs
    |> Enum.uniq_by(fn {address, _} -> address end)
    |> Enum.each(fn {address_id, _} ->
      AddressEvents.broadcast(address_id, msg)
    end)
  end
end
