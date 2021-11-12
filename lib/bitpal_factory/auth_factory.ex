defmodule BitPalFactory.AuthFactory do
  alias BitPal.Accounts
  alias BitPal.Authentication.Tokens
  alias BitPalFactory.AccountFactory
  alias BitPalFactory.StoreFactory
  alias BitPalSchemas.Store

  def valid_token_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      label: Faker.Pokemon.location()
    })
  end

  @spec create_token(Store.t(), map) :: Token.t()
  def create_token(store = %Store{}, attrs \\ %{}) do
    {:ok, token} = Tokens.create_token(store, valid_token_attributes(attrs))
    token
  end

  @spec create_auth(map) :: %{store_id: Store.id(), token: String.t()}
  def create_auth(attrs \\ %{}) do
    store = StoreFactory.get_or_create_store(attrs)

    %{
      store_id: store.id,
      token: create_token(store).data
    }
  end

  @spec get_or_create_user(map) :: User.t()
  def get_or_create_user(%{user: user}), do: user
  def get_or_create_user(%{user_id: user_id}), do: Accounts.get_user!(user_id)
  def get_or_create_user(_), do: AccountFactory.create_user()
end
