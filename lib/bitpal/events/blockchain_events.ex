defmodule BitPal.BlockchainEvents do
  alias BitPal.Currencies
  alias BitPal.EventHelpers
  alias BitPalSchemas.Currency

  @type height :: non_neg_integer()
  @type msg ::
          {:set_block_height, Currency.id(), height}
          | {:new_block, Currency.id(), height}
          | {:block_reversed, Currency.id(), height}

  @spec subscribe(Currency.id()) :: :ok | {:error, term}
  def subscribe(id) do
    EventHelpers.subscribe(topic(id))
  end

  @spec broadcast(Currency.id(), msg) :: :ok | {:error, term}
  def broadcast(id, msg) do
    EventHelpers.broadcast(topic(id), msg)
  end

  defp topic(id) do
    "blockchain:" <> Currencies.normalize(id)
  end
end
