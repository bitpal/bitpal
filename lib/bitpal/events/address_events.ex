defmodule BitPal.AddressEvents do
  alias BitPal.EventHelpers
  alias BitPalSchemas.Address
  alias BitPalSchemas.Transaction

  @type height :: non_neg_integer
  @type msg ::
          {{:tx, :pending}, %{id: Transaction.id(), address_id: Address.id()}}
          | {{:tx, :confirmed}, %{id: Transaction.id(), address_id: Address.id(), height: height}}
          | {{:tx, :double_spent}, %{id: Transaction.id(), address_id: Address.id()}}
          | {{:tx, :reversed}, %{id: Transaction.id(), address_id: Address.id()}}
          | {{:tx, :failed}, %{id: Transaction.id(), address_id: Address.id()}}

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
