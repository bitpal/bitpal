defmodule BitPal.Blocks do
  alias BitPal.BlockchainEvents
  alias BitPal.Currencies
  alias BitPalSchemas.Currency

  @type currency_id :: Currency.id()
  @type height :: non_neg_integer()

  @spec fetch_block_height!(currency_id) :: height
  def fetch_block_height!(currency_id) do
    Currencies.fetch_height!(currency_id)
  end

  @spec fetch_block_height(currency_id) :: {:ok, height} | :error
  def fetch_block_height(currency_id) do
    Currencies.fetch_height(currency_id)
  end

  @spec new_block(currency_id, height) :: :ok | {:error, term}
  def new_block(currency_id, height) do
    Currencies.set_height!(currency_id, height)
    BlockchainEvents.broadcast(currency_id, {{:block, :new}, currency_id, height})
  end

  @spec set_block_height(currency_id, height) :: :ok | {:error, term}
  def set_block_height(currency_id, height) do
    Currencies.set_height!(currency_id, height)
    BlockchainEvents.broadcast(currency_id, {{:block, :set_height}, currency_id, height})
  end

  @spec block_reversed(currency_id, height) :: :ok | {:error, term}
  def block_reversed(currency_id, height) do
    Currencies.set_height!(currency_id, height)
    BlockchainEvents.broadcast(currency_id, {{:block, :reversed}, currency_id, height})
  end
end
