defmodule BitPal.AddressEvents do
  alias BitPal.EventHelpers
  alias BitPalSchemas.Address
  alias BitPalSchemas.Transaction

  @type msg ::
          {:tx_seen, Transaction.t()}
          | {:tx_confirmed, Transaction.t()}
          | {:tx_double_spent, Transaction.t()}
          | {:tx_reversed, Transaction.t()}

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