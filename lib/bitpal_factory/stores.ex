defmodule BitPalFactory.Stores do
  alias BitPal.Stores
  alias BitPalSchemas.Store
  alias BitPalSchemas.User
  alias BitPal.Authentication.Tokens

  def with_token(store = %Store{}, attrs \\ %{}) do
    insert_token(store, attrs)
    store
  end

  def insert_token(store = %Store{}, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        label: Faker.Pokemon.location()
      })

    Tokens.create_token!(store, attrs)
  end

  def assoc_user(store = %Store{}, user = %User{}) do
    Stores.assoc_user(store, user)
  end

  @spec get_or_insert_store(map) :: Store.t()
  def get_or_insert_store(%{store_id: store_id}), do: Stores.fetch!(store_id)
  def get_or_insert_store(%{store: store}), do: store
  def get_or_insert_store(_), do: BitPalFactory.insert(:store)

  @spec get_or_insert_store_id(map) :: Store.id()
  def get_or_insert_store_id(%{store_id: store_id}), do: store_id
  def get_or_insert_store_id(%{store: store}), do: store.id
  def get_or_insert_store_id(_), do: BitPalFactory.insert(:store).id
end
