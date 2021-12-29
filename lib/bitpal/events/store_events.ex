defmodule BitPal.StoreEvents do
  @moduledoc """
  Invoice update events.
  """

  alias BitPal.EventHelpers
  alias BitPalSchemas.Address
  alias BitPalSchemas.Currency
  alias BitPalSchemas.Invoice
  alias BitPalSchemas.Store

  @type msg ::
          {{:store, :invoice_created}, %{id: Store.id(), invoice_id: Invoice.id()}}
          | {{:store, :address_created},
             %{id: Store.id(), address_id: Address.id(), currency_id: Currency.id()}}

  @spec subscribe(Store.id() | Store.t()) :: :ok | {:error, term}
  def subscribe(%Store{id: id}), do: EventHelpers.subscribe(topic(id))
  def subscribe(id), do: EventHelpers.subscribe(topic(id))

  @spec broadcast(msg) :: :ok | {:error, term}
  def broadcast(msg = {_, %{id: id}}) do
    EventHelpers.broadcast(topic(id), msg)
  end

  @spec topic(Store.id()) :: binary
  defp topic(store_id) do
    "store:#{store_id}"
  end
end
