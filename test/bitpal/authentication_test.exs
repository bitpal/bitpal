defmodule TokensTest do
  # NOTE would love to have this async, but the db interferes with the other tests...
  use ExUnit.Case, async: false
  import BitPal.CreationHelpers
  alias BitPal.Authentication.Tokens
  alias BitPal.Repo
  alias BitPal.Stores
  alias Ecto.Adapters.SQL.Sandbox

  setup do
    start_supervised(BitPal.Repo)
    :ok = Sandbox.checkout(BitPal.Repo)

    store = create_store()
    %{store: store}
  end

  test "create and associate", %{store: store} do
    a = Tokens.create_token!(store)
    # Cannot create a token the exact same system time with the same data
    Process.sleep(1)
    b = Tokens.create_token!(store)

    store = Stores.fetch!(store.id) |> Repo.preload([:access_tokens])
    assert length(store.access_tokens)
    assert a in store.access_tokens
    assert b in store.access_tokens
  end

  test "validate token", %{store: store} do
    a = Tokens.create_token!(store)
    store_id = store.id
    assert {:ok, ^store_id} = Tokens.authenticate_token(a.data)
  end

  test "invalid token", %{store: store} do
    Tokens.create_token!(store)
    token = Phoenix.Token.sign("bad-secret:tntntntntatasasitututututututututut", "salt", store.id)
    assert {:error, :invalid} = Tokens.authenticate_token(token)
  end

  test "correctly associated token", %{store: store} do
    a = Tokens.create_token!(store)
    other_store = create_store()
    assert {:error, :not_found} = Tokens.valid_token?(other_store.id, a.data)
  end

  test "deleted token", %{store: store} do
    a = Tokens.create_token!(store)
    Tokens.delete_token!(a)
    assert {:error, :not_found} = Tokens.valid_token?(store.id, a.data)
  end
end
