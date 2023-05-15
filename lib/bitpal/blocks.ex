defmodule BitPal.Blocks do
  import Ecto.Query
  alias BitPal.Repo
  alias BitPal.BlockchainEvents
  alias BitPalSchemas.Currency
  alias Ecto.Changeset

  @type currency_id :: Currency.id()
  @type height :: non_neg_integer()

  # Rename to shorten these

  @spec get_height(currency_id) :: height | nil
  def get_height(currency_id) do
    from(c in Currency, where: c.id == ^currency_id, select: c.block_height)
    |> Repo.one()
  end

  @spec fetch_height(currency_id) :: {:ok, height} | :error
  def fetch_height(currency_id) do
    case get_height(currency_id) do
      nil -> :error
      height -> {:ok, height}
    end
  rescue
    _ -> :error
  end

  @spec fetch_height!(currency_id) :: height
  def fetch_height!(currency_id) do
    case fetch_height(currency_id) do
      {:ok, height} -> height
      :error -> raise "Missing block height for: #{currency_id}"
    end
  end

  @spec new_block(currency_id, height) :: :ok
  def new_block(currency_id, height) do
    update_height(currency_id, height)

    BlockchainEvents.broadcast(
      currency_id,
      {{:block, :new}, %{currency_id: currency_id, height: height}}
    )
  end

  @spec set_height(currency_id, height) :: :ok
  def set_height(currency_id, height) do
    update_height(currency_id, height)

    BlockchainEvents.broadcast(
      currency_id,
      {{:block, :set_height}, %{currency_id: currency_id, height: height}}
    )
  end

  @spec block_reversed(currency_id, height) :: :ok | {:error, term}
  def block_reversed(currency_id, height) do
    update_height(currency_id, height)

    BlockchainEvents.broadcast(
      currency_id,
      {{:block, :reversed}, %{currency_id: currency_id, height: height}}
    )
  end

  @spec update_height(currency_id, height) :: :ok
  def update_height(currency_id, height) do
    case Repo.get(Currency, currency_id) do
      nil -> %Currency{id: currency_id}
      currency -> currency
    end
    |> Changeset.change(block_height: height)
    |> Repo.insert_or_update!()
  end
end
