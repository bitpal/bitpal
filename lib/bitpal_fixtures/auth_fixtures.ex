defmodule BitPalFixtures.AuthFixtures do
  alias BitPalSchemas.Store
  alias BitPal.Authentication.Tokens
  alias BitPalFixtures.StoreFixtures

  def valid_token_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      label: Faker.Pokemon.location()
    })
  end

  @spec token_fixture(Store.t(), map) :: Token.t()
  def token_fixture(store = %Store{}, attrs \\ %{}) do
    {:ok, token} = Tokens.create_token(store, valid_token_attributes(attrs))
    token
  end

  @spec auth_fixture(map) :: %{store_id: Store.id(), token: String.t()}
  def auth_fixture(attrs \\ %{}) do
    store =
      if store = attrs[:store] do
        store
      else
        StoreFixtures.store_fixture(attrs)
      end

    token = token_fixture(store)

    %{
      store_id: store.id,
      token: token.data
    }
  end
end
