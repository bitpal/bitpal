defmodule BitPal.Stores do
  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]
  alias BitPal.Invoices
  alias BitPal.Repo
  alias BitPal.UserEvents
  alias BitPalSchemas.AccessToken
  alias BitPalSchemas.Address
  alias BitPalSchemas.AddressKey
  alias BitPalSchemas.CurrencySettings
  alias BitPalSchemas.Invoice
  alias BitPalSchemas.Store
  alias BitPalSchemas.TxOutput
  alias BitPalSchemas.User
  alias Ecto.Changeset

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

  @spec fetch_by_invoice(Invoice.id()) :: {:ok, Store.t()} | :error
  def fetch_by_invoice(invoice_id) do
    res =
      from(s in Store,
        left_join: i in Invoice,
        on: i.store_id == s.id,
        where: i.id == ^invoice_id
      )
      |> Repo.one()

    if res do
      {:ok, res}
    else
      :error
    end
  end

  @spec has_invoice?(Store.id(), Invoice.id()) :: boolean
  def has_invoice?(store_id, invoice_id) do
    from(i in Invoice,
      where: i.id == ^invoice_id and i.store_id == ^store_id
    )
    |> Repo.exists?()
  end

  @spec create_changeset(map) :: Changeset.t()
  def create_changeset(params \\ %{}) do
    %Store{}
    |> change()
    |> cast(params, [:label])
    |> validate_required([:label])
    |> validate_length(:label, min: 1)
    |> create_slug()
  end

  @spec create_changeset(User.t(), map) :: Changeset.t()
  def create_changeset(user = %User{}, params) do
    %Store{users: [user]}
    |> change()
    |> cast(params, [:label])
    |> validate_required([:label])
    |> validate_length(:label, min: 1)
    |> create_slug()
  end

  @spec create(map | Changeset.t()) :: {:ok, Store.t()} | {:error, Changeset.t()}
  def create(changeset = %Changeset{}) do
    case Repo.insert(changeset) do
      {:ok, store} ->
        store = Repo.preload(store, :users)

        for user <- store.users do
          UserEvents.broadcast({{:user, :store_created}, %{user_id: user.id, store: store}})
        end

        {:ok, store}

      err ->
        err
    end
  end

  def create(params) do
    create_changeset(params)
    |> create()
  end

  @spec create(User.t(), map) :: {:ok, Store.t()} | {:error, Changeset.t()}
  def create(user = %User{}, params) do
    create_changeset(user, params)
    |> create()
  end

  @spec update_changeset(Store.t(), map) :: Changeset.t()
  def update_changeset(store, params \\ %{}) do
    store
    |> change()
    |> cast(params, [:label])
    |> validate_required([:label])
    |> validate_length(:label, min: 1)
  end

  @spec update(Store.t(), map) :: {:ok, Store.t()} | {:error, Changeset.t()}
  def update(store = %Store{}, params) do
    update_changeset(store, params)
    |> update()
  end

  @spec update(Changeset.t()) :: {:ok, Store.t()} | {:error, Changeset.t()}
  def update(changeset) do
    changeset
    |> Repo.update()
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

  @spec all_addresses(Store.id() | Store.t()) :: [Address.t()]
  def all_addresses(store = %Store{}) do
    all_addresses(store.id)
  end

  def all_addresses(store_id) do
    from(a in Address,
      left_join: i in Invoice,
      on: a.id == i.address_id,
      left_join: key in AddressKey,
      on: a.address_key_id == key.id,
      left_join: settings in CurrencySettings,
      on: key.currency_settings_id == settings.id,
      where: i.store_id == ^store_id or settings.store_id == ^store_id,
      select: a,
      order_by: [asc: a.inserted_at, asc: a.address_index]
    )
    |> Repo.all()
  end

  @spec find_token(Store.t(), AccessToken.id()) :: {:ok, AccessToken.t()} | {:error, :not_found}
  def find_token(store, token_id) when is_integer(token_id) do
    case Enum.find(store.access_tokens, fn token -> token.id == token_id end) do
      nil -> {:error, :not_found}
      token -> {:ok, token}
    end
  end

  def find_token(_store, _token_id) do
    {:error, :not_found}
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

  defp slugified_label(label) do
    label
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s-]/, "")
    |> String.replace(~r/(\s|-)+/, "-")
  end

  @spec load_invoices(Store.t()) :: Store.t()
  def load_invoices(store) do
    store = Repo.preload(store, :invoices)
    %{store | invoices: Enum.map(store.invoices, &Invoices.update_expected_payment/1)}
  end
end
