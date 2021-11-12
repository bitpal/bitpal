defmodule BitPal.StoreTest do
  use BitPal.DataCase, async: true
  alias BitPal.Repo

  setup _tags do
    %{store: insert(:store)}
  end

  describe "assoc_user/2" do
    test "assoc multiple users", %{store: store} do
      user1 = insert(:user)
      Stores.assoc_user(store, user1)

      user2 = insert(:user)
      Stores.assoc_user(store, user2)

      expected_user_ids = Enum.into([user1.id, user2.id], MapSet.new())

      store = Repo.preload(store, :users, force: true)

      found_user_ids =
        store.users
        |> Enum.map(& &1.id)
        |> Enum.into(MapSet.new())

      assert expected_user_ids == found_user_ids
    end
  end
end
