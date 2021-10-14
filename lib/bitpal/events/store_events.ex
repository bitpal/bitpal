defmodule BitPal.StoreEvents do
  @moduledoc """
  Invoice update events.
  """

  alias BitPal.EventHelpers
  alias BitPalSchemas.Store
  alias BitPalSchemas.Invoice

  @type msg ::
          {:invoice_created, %{id: Store.id(), invoice_id: Invoice.id()}}

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
