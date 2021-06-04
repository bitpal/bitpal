defmodule BitPal.BlockchainEvents do
  alias BitPal.Currencies
  alias BitPal.EventHelpers
  alias BitPalSchemas.Currency

  @type currency_id :: Currency.id()
  @type height :: non_neg_integer()
  @type msg ::
          {:set_block_height, currency_id, height}
          | {:new_block, currency_id, height}
          | {:block_reversed, currency_id, height}

  @spec subscribe(currency_id) :: :ok | {:error, term}
  def subscribe(currency_id) do
    EventHelpers.subscribe(topic(currency_id))
  end

  @spec broadcast(currency_id, msg) :: :ok | {:error, term}
  def broadcast(currency_id, msg) do
    EventHelpers.broadcast(topic(currency_id), msg)
  end

  defp topic(currency_id) do
    "blockchain:" <> Currencies.normalize(currency_id)
  end
end
