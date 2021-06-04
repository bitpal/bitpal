defmodule BitPal.Blocks do
  alias BitPal.BlockchainEvents
  alias BitPal.Currencies
  alias BitPal.RuntimeStorage
  alias BitPalSchemas.Currency

  @type currency_id :: Currency.id()
  @type height :: non_neg_integer()

  def fetch_block_height(currency_id) do
    RuntimeStorage.fetch(height_id(currency_id))
  end

  def fetch_block_height!(currency_id) do
    case fetch_block_height(currency_id) do
      {:ok, res} -> res
      _ -> raise RuntimeError, "no block height for #{currency_id}"
    end
  end

  @spec new_block(currency_id, height) :: :ok | {:error, term}
  def new_block(currency_id, height) do
    RuntimeStorage.put(height_id(currency_id), height)
    BlockchainEvents.broadcast(currency_id, {:new_block, currency_id, height})
  end

  @spec set_block_height(currency_id, height) :: :ok | {:error, term}
  def set_block_height(currency_id, height) do
    RuntimeStorage.put(height_id(currency_id), height)
    BlockchainEvents.broadcast(currency_id, {:set_block_height, currency_id, height})
  end

  @spec block_reversed(currency_id, height) :: :ok | {:error, term}
  def block_reversed(currency_id, height) do
    RuntimeStorage.put(height_id(currency_id), height)
    BlockchainEvents.broadcast(currency_id, {:block_reversed, currency_id, height})
  end

  defp height_id(currency_id) do
    {:height, Currencies.normalize(currency_id)}
  end
end
