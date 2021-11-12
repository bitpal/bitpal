defmodule BitPalFactory.Auth do
  import BitPalFactory.Stores

  def generate_auth(attrs \\ %{}) do
    store = get_or_insert_store(attrs)
    token = insert_token(store)

    %{
      store_id: store.id,
      token: token.data
    }
  end
end
