defmodule BitPalFixtures.TransactionFixturesTest do
  use BitPal.DataCase, async: true

  describe "unique_txid" do
    test "generate txs" do
      Enum.reduce(0..10, MapSet.new(), fn _, seen ->
        txid = TransactionFixtures.unique_txid()
        assert !MapSet.member?(seen, txid), "Duplicate txid generated #{txid} #{inspect(seen)}"
        MapSet.put(seen, txid)
      end)
    end
  end
end
