defmodule BitPal.BlocksTest do
  use BitPal.DataCase, async: true
  alias BitPal.Blocks
  alias BitPal.BlockchainEvents

  setup _tags do
    id = unique_currency_id()
    BlockchainEvents.subscribe(id)
    %{currency_id: id}
  end

  describe "new" do
    test "new block", %{currency_id: id} do
      Blocks.new(id, 1, "a")
      assert_receive {{:block, :new}, %{currency_id: ^id, height: 1}}
      assert Blocks.get_height(id) == 1

      Blocks.new(id, 2, "b")
      assert_receive {{:block, :new}, %{currency_id: ^id, height: 2}}
      assert Blocks.get_height(id) == 2
    end

    test "ignore same block", %{currency_id: id} do
      Blocks.new(id, 1, "a")
      assert_receive {{:block, :new}, %{currency_id: ^id, height: 1}}
      Blocks.new(id, 1, "a")
      refute_receive {{:block, :new}, %{currency_id: ^id, height: 1}}
      assert Blocks.get_height(id) == 1
    end

    test "send same block with nil", %{currency_id: id} do
      Blocks.new(id, 1, "a")
      assert_receive {{:block, :new}, %{currency_id: ^id, height: 1}}
      Blocks.new(id, 1)
      assert_receive {{:block, :new}, %{currency_id: ^id, height: 1}}
      assert Blocks.get_height(id) == 1
    end
  end

  describe "reorg" do
    test "sends event", %{currency_id: id} do
      Blocks.new(id, 3, "a")

      Blocks.reorg(id, 3, 2, "x")
      assert_receive {{:block, :reorg}, %{currency_id: ^id, new_height: 3, split_height: 2}}
    end

    test "ignore event", %{currency_id: id} do
      Blocks.new(id, 3, "a")

      Blocks.reorg(id, 3, 2, "a")
      refute_receive {{:block, :reorg}, %{currency_id: ^id, new_height: 3, split_height: 2}}
    end

    test "send with nil", %{currency_id: id} do
      Blocks.new(id, 3, "a")

      Blocks.reorg(id, 3, 2)
      assert_receive {{:block, :reorg}, %{currency_id: ^id, new_height: 3, split_height: 2}}
    end
  end
end
