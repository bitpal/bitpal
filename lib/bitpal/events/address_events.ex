defmodule BitPal.AddressEvents do
  alias BitPal.EventHelpers
  alias BitPalSchemas.Address
  alias BitPalSchemas.TxOutput

  @type height :: non_neg_integer
  @type msg ::
          {:tx_seen, TxOutput.txid()}
          | {:tx_confirmed, TxOutput.txid(), height}
          | {:tx_double_spent, TxOutput.txid()}
          | {:tx_reversed, TxOutput.txid()}

  @spec subscribe(Address.id()) :: :ok | {:error, term}
  def subscribe(address_id) do
    EventHelpers.subscribe(topic(address_id))
  end

  @spec broadcast(Address.id(), msg) :: :ok | {:error, term}
  def broadcast(address_id, msg) do
    EventHelpers.broadcast(topic(address_id), msg)
  end

  defp topic(address_id) do
    "address:" <> address_id
  end
end
