defmodule BitPal.Stores do
  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]
  alias BitPal.Repo
  alias BitPalSchemas.Invoice
  alias BitPalSchemas.Store
  alias BitPalSchemas.User
  alias BitPalSchemas.TxOutput

  @spec fetch(non_neg_integer) :: {:ok, Store.t()} | :error
  def fetch(id) do
    if store = Repo.get(Store, id) do
      {:ok, store}
    else
      :error
    end
  end

  @spec fetch!(non_neg_integer) :: Store.t()
  def fetch!(id) do
    {:ok, store} = fetch(id)
    store
  end

  @spec create!(keyword) :: Store.t()
  def create!(params \\ []) do
    Repo.insert!(%Store{label: params[:label]})
  end

  @spec create(User.t(), map) :: {:ok, Store.t()} | {:error, Changeset.t()}
  def create(user, params) do
    %Store{users: [user]}
    |> cast(params, [:label])
    |> validate_required([:label])
    |> Repo.insert()
  end

  @spec all :: [Store.t()]
  def all do
    Repo.all(Store)
  end

  @spec user_stores(User.t()) :: [Store.t()]
  def user_stores(user) do
    user = user |> Repo.preload(:stores)
    user.stores
  end

  @spec tx_outputs(Store.id()) :: [TxOutput.t()]
  def tx_outputs(store_id) do
    from(t in TxOutput,
      left_join: i in Invoice,
      on: t.address_id == i.address_id,
      where: i.store_id == ^store_id
    )
    |> Repo.all()
  end
end
