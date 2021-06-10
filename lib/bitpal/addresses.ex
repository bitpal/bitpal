defmodule BitPal.Addresses do
  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]
  alias BitPal.Currencies
  alias BitPal.Repo
  alias BitPalSchemas.Address
  alias BitPalSchemas.Currency
  alias BitPalSchemas.Invoice
  alias Ecto.Multi

  @type address_index :: non_neg_integer

  @spec get(String.t()) :: Address.t() | nil
  def get(address_id) do
    from(a in Address, where: a.id == ^address_id)
    |> Repo.one()
  end

  @spec exists?(String.t()) :: boolean
  def exists?(address_id) do
    from(a in Address, where: a.id == ^address_id)
    |> Repo.exists?()
  end

  @spec register(Currency.id(), [{Address.id(), address_index}]) ::
          {:ok, %{String.t() => Address.t()}} | {:error, Ecto.Changeset.t()}
  def register(currency, addresses) do
    Enum.reduce(addresses, Multi.new(), fn {address, index}, multi ->
      Multi.insert(multi, address, register_changeset(currency, address, index))
    end)
    |> Repo.transaction()
  end

  @spec register(Currency.id(), Address.id(), address_index) ::
          {:ok, Address.t()} | {:error, Ecto.Changeset.t()}
  def register(currency, address, address_index) do
    register_changeset(currency, address, address_index)
    |> Repo.insert()
  end

  @spec register_with(Currency.id(), (address_index -> Address.id())) ::
          {:ok, Address.t()} | {:error, Ecto.Changeset.t()}
  def register_with(currency, address_generator) do
    address_index = next_address_index(currency)
    address_id = address_generator.(address_index)
    register(currency, address_id, address_index)
  end

  @spec register_next_address(Currency.id(), Address.id()) ::
          {:ok, Address.t()} | {:error, Ecto.Changeset.t()}
  def register_next_address(currency_id, address_id) do
    register(currency_id, address_id, next_address_index(currency_id))
  end

  @spec register_changeset(Currency.id(), Address.id(), address_index) :: Ecto.Changeset.t()
  defp register_changeset(currency, address, address_index) do
    change(%Address{
      id: address,
      generation_index: address_index,
      currency_id: Currencies.normalize(currency)
    })
    |> assoc_constraint(:currency)
    |> unique_constraint(:id, name: :addresses_pkey)
    |> unique_constraint([:generation_index, :currency_id])
  end

  @doc """
  When generating addresses we track an unique index for each generation. This returns
  the next index, increasing from 0.
  """
  @spec next_address_index(Currency.id()) :: address_index
  def next_address_index(currency) do
    case from(a in Address,
           where: a.currency_id == ^Currencies.normalize(currency),
           select: max(a.generation_index)
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
  @spec find_unused_address(Currency.id()) :: Address.t() | nil
  def find_unused_address(currency) do
    # How to select rows with no matching entry in another table:
    # https://stackoverflow.com/questions/4076098/how-to-select-rows-with-no-matching-entry-in-another-table
    from(a in Address,
      where: a.currency_id == ^Currencies.normalize(currency),
      left_join: i in Invoice,
      on: i.address_id == a.id,
      where: is_nil(i.address_id),
      limit: 1
    )
    |> Repo.one()
  end
end
