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

  @spec create(map) :: {:ok, Store.t()} | {:error, Changeset.t()}
  def create(params) do
    %Store{}
    |> create(params)
  end

  @spec create(User.t(), map) :: {:ok, Store.t()} | {:error, Changeset.t()}
  def create(user = %User{}, params) do
    %Store{users: [user]}
    |> create(params)
  end

  @spec create(Store.t(), map) :: {:ok, Store.t()} | {:error, Changeset.t()}
  def create(store = %Store{}, params) do
    store
    |> cast(params, [:label])
    |> validate_required([:label])
    |> create_slug()
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

  @spec assoc_user(Store.t(), User.t()) :: Store.t()
  def assoc_user(store = %Store{}, user = %User{}) do
    store = Repo.preload(store, :users)

    store
    |> change()
    |> put_assoc(:users, [user | store.users])
    |> Repo.update!()
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

  defp create_slug(changeset) do
    case get_field(changeset, :label) do
      nil ->
        changeset

      label ->
        changeset
        |> change(slug: slugified_label(label))
    end
  end

  def slugified_label(label) do
    label
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s-]/, "")
    |> String.replace(~r/(\s|-)+/, "-")
  end
end
