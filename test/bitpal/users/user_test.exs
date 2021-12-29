defmodule BitPal.UserTest do
  use BitPal.DataCase, async: true
  alias BitPal.Accounts
  alias BitPal.Repo
  alias BitPal.Stores

  test "user store association" do
    {:ok, user} =
      Accounts.register_user(%{email: "test@bitpal.dev", password: "test_test_test_test"})

    {:ok, store} = Stores.create(user, %{label: "My Store"})

    user = Repo.preload(user, [:stores])
    assert length(user.stores) == 1
    assert hd(user.stores).id == store.id

    store = Repo.preload(store, [:users])
    assert length(store.users) == 1
    assert hd(store.users).id == user.id
  end
end
