defmodule BitPal.AccessTokensTest do
  # NOTE would love to have this async, but the db interferes with the other tests...
  use ExUnit.Case, async: false
  import BitPal.TestHelpers
  alias BitPal.Authentication
  alias BitPal.Repo
  alias BitPal.Stores
  alias Ecto.Adapters.SQL.Sandbox

  setup do
    start_supervised(BitPal.Repo)
    :ok = Sandbox.checkout(BitPal.Repo)

    %{store: create_store()}
  end

  test "create and associate", %{store: store} do
    a = Authentication.create_token!(store)
    b = Authentication.create_token!(store)

    store = store |> Repo.preload([:access_tokens], force: true)
    assert length(store.access_tokens)
    assert a in store.access_tokens
    assert b in store.access_tokens
  end

  test "validate token", %{store: store} do
    a = Authentication.create_token!(store)
    assert {:ok, store.id} == Authentication.authenticate_token(a.data)
  end

  test "invalid token", %{store: store} do
    Authentication.create_token!(store)
    token = Phoenix.Token.sign("bad-secret:tntntntntatasasitututututututututut", "salt", store.id)
    assert {:error, :invalid} = Authentication.authenticate_token(token)
  end

  test "correctly associated token", %{store: store} do
    a = Authentication.create_token!(store)
    other_store = create_store()
    assert {:error, :not_found} = Authentication.valid_token?(other_store.id, a.data)
  end

  test "deleted token", %{store: store} do
    a = Authentication.create_token!(store)
    Authentication.delete_token!(a)
    assert {:error, :not_found} = Authentication.valid_token?(store.id, a.data)
  end
end
