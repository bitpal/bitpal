defmodule BitPal.Blocks do
  import Ecto.Query
  alias BitPal.BlockchainEvents
  alias BitPal.Currencies
  alias BitPal.Repo
  alias BitPalSchemas.Currency

  @type currency_id :: Currency.id()
  @type height :: non_neg_integer()

  @spec get_block_height(currency_id) :: height | nil
  def get_block_height(currency_id) do
    from(c in Currency,
      where: c.id == ^Currencies.normalize(currency_id),
      select: c.block_height
    )
    |> Repo.one()
  end

  @spec fetch_block_height(currency_id) :: {:ok, height} | :error
  def fetch_block_height(currency_id) do
    case get_block_height(currency_id) do
      nil -> :error
      height -> {:ok, height}
    end
  end

  @spec new_block(currency_id, height) :: :ok | {:error, term}
  def new_block(currency_id, height) do
    Currencies.set_height!(currency_id, height)
    BlockchainEvents.broadcast(currency_id, {:new_block, currency_id, height})
  end

  @spec set_block_height(currency_id, height) :: :ok | {:error, term}
  def set_block_height(currency_id, height) do
    Currencies.set_height!(currency_id, height)
    BlockchainEvents.broadcast(currency_id, {:set_block_height, currency_id, height})
  end

  @spec block_reversed(currency_id, height) :: :ok | {:error, term}
  def block_reversed(currency_id, height) do
    Currencies.set_height!(currency_id, height)
    BlockchainEvents.broadcast(currency_id, {:block_reversed, currency_id, height})
  end
end
