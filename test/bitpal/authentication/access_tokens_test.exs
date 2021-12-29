defmodule BitPal.AccessTokensTest do
  use BitPal.DataCase, async: true
  alias BitPal.Authentication.Tokens
  alias BitPal.Repo
  alias BitPalSchemas.AccessToken

  setup do
    %{store: create_store()}
  end

  describe "create_token" do
    test "create and associate", %{store: store} do
      now = System.system_time(:second)
      a = create_token(store, signed_at: now - 1)
      b = create_token(store, signed_at: now)

      store = store |> Repo.preload([:access_tokens], force: true)
      assert length(store.access_tokens)
      assert a in store.access_tokens
      assert b in store.access_tokens
    end
  end

  describe "authenticate_token" do
    test "valid token", %{store: store} do
      t = create_token(store)
      assert {:ok, store.id} == Tokens.authenticate_token(t.data)
    end

    test "valid token within exparation date", %{store: store} do
      signed_at = System.system_time(:second)
      valid_until = (signed_at + 2) |> DateTime.from_unix!() |> DateTime.to_naive()

      t = create_token(store, signed_at: signed_at, valid_until: valid_until)
      assert {:ok, store.id} == Tokens.authenticate_token(t.data)
    end

    test "invalid token outside exparation date", %{store: store} do
      signed_at = System.system_time(:second) - 2
      valid_until = (signed_at + 1) |> DateTime.from_unix!() |> DateTime.to_naive()

      t = create_token(store, signed_at: signed_at, valid_until: valid_until)
      assert {:error, :expired} == Tokens.authenticate_token(t.data)
    end

    test "invalid token from other store", %{store: store} do
      t = create_token(store)
      Tokens.delete_token!(t)
      assert {:error, :invalid} = Tokens.authenticate_token(t.data)
    end

    test "invalid nonsense token", %{store: store} do
      store |> with_token()

      token =
        Phoenix.Token.sign("bad-secret:tntntntntatasasitututututututututut", "salt", store.id)

      assert {:error, :invalid} = Tokens.authenticate_token(token)
    end

    test "updates last_accessed", %{store: store} do
      t = create_token(store)
      assert t.last_accessed == nil

      now = NaiveDateTime.utc_now()
      assert {:ok, _} = Tokens.authenticate_token(t.data)

      t = Repo.get!(AccessToken, t.id)
      assert t.last_accessed
      assert NaiveDateTime.diff(t.last_accessed, now) <= 2
    end
  end

  describe "valid_age" do
    test "nil valid_until gives infinity", %{store: store} do
      assert create_token(store, valid_until: nil)
             |> Tokens.valid_age() == :infinity
    end

    test "diff seconds", %{store: store} do
      # We can't control the virication time, so add a tolerance so tests have some leeway.
      tolerance = 5
      valid_until = NaiveDateTime.add(NaiveDateTime.utc_now(), tolerance)

      valid_age =
        create_token(store, valid_until: valid_until)
        |> Tokens.valid_age()

      assert valid_age > 0 && valid_age <= tolerance
    end
  end

  describe "get_token" do
    test "get associated token", %{store: store} do
      t = create_token(store)
      assert {:ok, got} = Tokens.get_token(t.data)
      assert t.id == got.id
    end

    test "can't get deleted token", %{store: store} do
      t = create_token(store)
      Tokens.delete_token!(t)
      assert {:error, :not_found} = Tokens.get_token(t.data)
    end
  end
end
