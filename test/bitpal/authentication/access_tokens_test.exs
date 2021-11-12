defmodule BitPal.AccessTokensTest do
  use BitPal.DataCase, async: true
  alias BitPal.Authentication.Tokens
  alias BitPal.Repo

  setup do
    %{store: create_store()}
  end

  test "create and associate", %{store: store} do
    a = Tokens.create_token!(store)
    # In a very odd case, they might be generated at the same time causing a collision
    :timer.sleep(1)
    b = Tokens.create_token!(store)

    store = store |> Repo.preload([:access_tokens], force: true)
    assert length(store.access_tokens)
    assert a in store.access_tokens
    assert b in store.access_tokens
  end

  test "validate token", %{store: store} do
    a = Tokens.create_token!(store)
    assert {:ok, store.id} == Tokens.authenticate_token(a.data)
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
