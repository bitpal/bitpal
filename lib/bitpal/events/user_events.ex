defmodule BitPal.UserEvents do
  @moduledoc """
  Invoice update events.
  """

  alias BitPal.EventHelpers
  alias BitPalSchemas.Address
  alias BitPalSchemas.Currency
  alias BitPalSchemas.Invoice
  alias BitPalSchemas.User

  @type msg :: {{:user, :store_created}, %{user_id: User.id(), store: Store.t()}}

  @spec subscribe(User.id() | User.t()) :: :ok | {:error, term}
  def subscribe(%User{id: id}), do: EventHelpers.subscribe(topic(id))
  def subscribe(id), do: EventHelpers.subscribe(topic(id))

  @spec broadcast(msg) :: :ok | {:error, term}
  def broadcast(msg = {_, %{user_id: id}}) do
    EventHelpers.broadcast(topic(id), msg)
  end

  @spec topic(User.id()) :: binary
  defp topic(user_id) do
    "user:#{user_id}"
  end
end
