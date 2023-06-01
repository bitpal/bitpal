defmodule BitPal.Blocks do
  import Ecto.Query
  alias BitPal.Repo
  alias BitPal.BlockchainEvents
  alias BitPalSchemas.Currency
  alias Ecto.Changeset

  @type currency_id :: Currency.id()
  @type height :: non_neg_integer()
  @type hash :: String.t()

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

  @spec new(currency_id, height, hash) :: :ok | :not_updated
  def new(currency_id, height, top_block \\ nil) do
    existing = Repo.get(Currency, currency_id)

    case existing do
      nil -> %Currency{id: currency_id}
      currency -> currency
    end
    |> Changeset.change(block_height: height, top_block_hash: top_block)
    |> Repo.insert_or_update!()

    if !existing || existing.top_block_hash != top_block || top_block == nil do
      BlockchainEvents.broadcast(
        currency_id,
        {{:block, :new}, %{currency_id: currency_id, height: height}}
      )

      :ok
    else
      :not_updated
    end
  end

  @spec reorg(currency_id, height, height, hash) :: :ok | :no_reorg
  def reorg(currency_id, new_height, split_height, new_top_block \\ nil) do
    existing = Repo.get(Currency, currency_id)

    case existing do
      nil -> %Currency{id: currency_id}
      currency -> currency
    end
    |> Changeset.change(block_height: new_height, top_block_hash: new_top_block)
    |> Repo.insert_or_update!()

    if existing && (existing.top_block_hash != new_top_block || new_top_block == nil) do
      BlockchainEvents.broadcast(
        currency_id,
        {{:block, :reorg},
         %{currency_id: currency_id, new_height: new_height, split_height: split_height}}
      )

      :ok
    else
      :no_reorg
    end
  end
end
