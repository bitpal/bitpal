defmodule BitPal.Addresses do
  import Ecto.Changeset
  import Ecto.Query
  alias BitPal.Invoices
  alias BitPal.Repo
  alias BitPal.StoreEvents
  alias BitPalSchemas.Address
  alias BitPalSchemas.AddressKey
  alias BitPalSchemas.Currency
  alias BitPalSchemas.Invoice
  alias BitPalSchemas.TxOutput
  alias BitPalSettings.StoreSettings
  alias Ecto.Changeset
  require Logger

  @type address_index :: non_neg_integer
  @type address_generator_res :: %{address_id: Address.id(), address_index: address_index}
  @type address_generator :: (AddressKey.t() -> address_generator_res)

  # Retrieve

  @spec get(String.t()) :: Address.t() | nil
  def get(address_id) do
    from(a in Address, where: a.id == ^address_id)
    |> Repo.one()
  end

  @spec get_by_txid(TxOutput.txid()) :: [Address.t()]
  def get_by_txid(txid) do
    from(a in Address,
      left_join: t in TxOutput,
      on: t.address_id == a.id,
      where: t.transaction_id == ^txid,
      select: a
    )
    |> Repo.all()
  end

  @spec exists?(String.t()) :: boolean
  def exists?(address_id) do
    from(a in Address, where: a.id == ^address_id)
    |> Repo.exists?()
  end

  @spec filter_exists([String.t()]) :: [String.t()]
  def filter_exists(addresses) do
    from(a in Address, where: a.id in ^addresses)
    |> Repo.all()
  end

  @spec all_active_ids(Currency.id()) :: [Address.id()]
  def all_active_ids(currency_id) do
    Invoice
    |> Invoices.with_status([:open, :processing])
    |> Invoices.with_currency(currency_id)
    |> select([i], i.address_id)
    |> Repo.all()
  end

  @spec all_active(Currency.id()) :: [Address.t()]
  def all_active(currency_id) do
    Invoice
    |> Invoices.with_status([:open, :processing])
    |> Invoices.with_currency(currency_id)
    |> join(:inner, [i], a in Address, on: a.id == i.address_id)
    |> select([i, a], a)
    |> Repo.all()
  end

  @spec all_open_ids(Currency.id()) :: [Address.id()]
  def all_open_ids(currency_id) do
    Invoice
    |> Invoices.with_status(:open)
    |> Invoices.with_currency(currency_id)
    |> select([i], i.address_id)
    |> Repo.all()
  end

  @spec open?(Address.t()) :: boolean
  def open?(address_id) do
    Invoice
    |> Invoices.with_status(:open)
    |> Invoices.with_address(address_id)
    |> Repo.exists?()
  end

  # Update

  @spec register(AddressKey.t(), Address.id(), address_index) ::
          {:ok, Address.t()} | {:error, Changeset.t()}
  def register(address_key, address_id, address_index) do
    res =
      %Address{
        id: address_id,
        address_index: address_index,
        currency_id: address_key.currency_id,
        address_key_id: address_key.id
      }
      |> change()
      |> assoc_constraint(:currency)
      |> assoc_constraint(:address_key)
      |> unique_constraint(:id, name: :addresses_pkey)
      |> unique_constraint([:address_index, :address_key_id])
      |> Repo.insert()

    case res do
      {:ok, address} ->
        case StoreSettings.address_key_store(address_key) do
          {:ok, store} ->
            StoreEvents.broadcast(
              {{:store, :address_created},
               %{id: store.id, address_id: address.id, currency_id: address.currency_id}}
            )

          _ ->
            nil
        end

        {:ok, address}

      err ->
        err
    end
  end

  @spec register_next_address(AddressKey.t(), Address.id()) ::
          {:ok, Address.t()} | {:error, Changeset.t()}
  def register_next_address(address_key, address_id) do
    address_index = next_address_index(address_key)
    register(address_key, address_id, address_index)
  end

  @spec generate_address(AddressKey.t(), address_generator) ::
          {:ok, Address.t()} | {:error, Changeset.t()}
  def generate_address(address_key, address_generator) do
    case address_generator.(address_key) do
      {:ok, %{address_id: address_id, address_index: address_index}} ->
        register(address_key, address_id, address_index)

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  When generating addresses we track an unique index for each generation. This returns
  the next index, increasing from 0.
  """
  @spec next_address_index(AddressKey.t()) :: address_index
  def next_address_index(address_key) do
    case from(a in Address,
           where: a.address_key_id == ^address_key.id,
           select: max(a.address_index)
         )
         |> Repo.one() do
      nil -> 0
      max -> max + 1
    end
  end

  @doc """
  Finds an unused address from the database that we can associate with an invoice,
  or nil if there's nothing to be found.

  Currently doesn't care about large gaps, but maybe we should avoid creating too large gaps?
  Otherwise the user experience when importing may suffer,
  but if we ever reuse an address for two invoices then privacy may suffer.
  """
  @spec find_unused_address(AddressKey.t()) :: Address.t() | nil
  def find_unused_address(address_key) do
    # How to select rows with no matching entry in another table:
    # https://stackoverflow.com/questions/4076098/how-to-select-rows-with-no-matching-entry-in-another-table
    from(a in Address,
      where: a.address_key_id == ^address_key.id,
      left_join: i in Invoice,
      on: i.address_id == a.id,
      where: is_nil(i.address_id),
      limit: 1
    )
    |> Repo.one()
  end
end
