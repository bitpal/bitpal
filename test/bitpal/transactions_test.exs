defmodule BitPal.TransactionsTest do
  use BitPal.IntegrationCase, async: true
  import TransactionFixtures
  alias BitPalSchemas.TxOutput

  setup tags do
    address = AddressFixtures.address_fixture()

    res = %{
      address: address,
      txid: TransactionFixtures.unique_txid()
    }

    if tags[:other_address] do
      other_address = AddressFixtures.address_fixture(currency_id: address.currency_id)

      Map.put(res, :other_address, other_address)
    else
      res
    end
  end

  describe "seen/2" do
    test "seen", %{address: address, txid: txid} do
      assert :ok = Transactions.seen(txid, [{address.id, money_fixture(address.currency_id)}])
      tx = Repo.get_by!(TxOutput, txid: txid)
      assert tx.txid == txid
      assert tx.address_id == address.id
      assert tx.confirmed_height == nil
    end

    test "2x output seen", %{address: address, txid: txid} do
      assert :ok =
               Transactions.seen(txid, [
                 {address.id, money_fixture(address.currency_id)},
                 {address.id, money_fixture(address.currency_id)}
               ])

      txs = Repo.all(TxOutput)

      assert Enum.count(txs) == 2

      Enum.each(txs, fn tx ->
        assert tx.txid == txid
        assert tx.address_id == address.id
        assert tx.confirmed_height == nil
      end)
    end

    @tag other_address: true
    test "2x output seen separate addresses", %{
      address: address,
      txid: txid,
      other_address: other_address
    } do
      assert :ok =
               Transactions.seen(txid, [
                 {address.id, money_fixture(address.currency_id)},
                 {other_address.id, money_fixture(address.currency_id)}
               ])

      tx0 = Repo.get_by!(TxOutput, txid: txid, address_id: address.id)
      assert tx0.txid == txid
      assert tx0.confirmed_height == nil

      tx1 = Repo.get_by!(TxOutput, txid: txid, address_id: other_address.id)
      assert tx1.txid == txid
      assert tx1.confirmed_height == nil
    end
  end

  describe "confirmed/2" do
    test "confirmed", %{address: address, txid: txid} do
      assert :ok =
               Transactions.confirmed(txid, [{address.id, money_fixture(address.currency_id)}], 0)

      tx = Repo.get_by!(TxOutput, txid: txid)
      assert tx.txid == txid
      assert tx.address_id == address.id
      assert tx.confirmed_height == 0
    end

    @tag other_address: true
    test "2x output confirmed separate addresses", %{
      address: address,
      txid: txid,
      other_address: other_address
    } do
      assert :ok =
               Transactions.seen(txid, [
                 {address.id, money_fixture(address.currency_id)},
                 {other_address.id, money_fixture(address.currency_id)}
               ])

      assert :ok =
               Transactions.confirmed(
                 txid,
                 [
                   {address.id, money_fixture(address.currency_id)},
                   {other_address.id, money_fixture(address.currency_id)}
                 ],
                 1
               )

      tx0 = Repo.get_by!(TxOutput, txid: txid, address_id: address.id)
      assert tx0.txid == txid
      assert tx0.address_id == address.id
      assert tx0.confirmed_height == 1

      tx1 = Repo.get_by!(TxOutput, txid: txid, address_id: other_address.id)
      assert tx1.txid == txid
      assert tx1.address_id == other_address.id
      assert tx1.confirmed_height == 1
    end

    test "seen then confirmed", %{address: address, txid: txid} do
      assert :ok = Transactions.seen(txid, [{address.id, money_fixture(address.currency_id)}])
      tx = Repo.get_by!(TxOutput, txid: txid)
      assert tx.confirmed_height == nil

      assert :ok =
               Transactions.confirmed(
                 txid,
                 [{address.id, money_fixture(address.currency_id)}],
                 1
               )

      tx2 = Repo.get_by!(TxOutput, txid: txid)
      assert tx.id == tx2.id
      assert tx2.confirmed_height == 1
    end
  end

  describe "reversed/2" do
    test "reversed", %{address: address, txid: txid} do
      assert :ok =
               Transactions.confirmed(
                 txid,
                 [{address.id, money_fixture(address.currency_id)}],
                 0
               )

      tx = Repo.get_by!(TxOutput, txid: txid)
      assert tx.confirmed_height == 0

      assert :ok = Transactions.reversed(txid, [{address.id, money_fixture(address.currency_id)}])

      tx = Repo.get_by!(TxOutput, txid: txid)
      assert tx.confirmed_height == nil
      assert !tx.double_spent
    end
  end

  describe "double_spent/2" do
    test "0-conf double spent", %{address: address, txid: txid} do
      assert :ok = Transactions.seen(txid, [{address.id, money_fixture(address.currency_id)}])
      tx = Repo.get_by!(TxOutput, txid: txid)
      assert !tx.double_spent

      assert :ok =
               Transactions.double_spent(txid, [
                 {address.id, money_fixture(address.currency_id)}
               ])

      tx = Repo.get_by!(TxOutput, txid: txid)
      assert tx.double_spent
    end

    test "failed delayed double spend attempt", %{address: address, txid: txid} do
      # It's possible to mark a transaction as both a double spend and as having a confirmation.
      # This means that the double spend attempt failed.
      assert :ok =
               Transactions.confirmed(
                 txid,
                 [{address.id, money_fixture(address.currency_id)}],
                 0
               )

      tx = Repo.get_by!(TxOutput, txid: txid)
      assert !tx.double_spent
      assert tx.confirmed_height == 0

      assert :ok =
               Transactions.double_spent(txid, [
                 {address.id, money_fixture(address.currency_id)}
               ])

      tx = Repo.get_by!(TxOutput, txid: txid)
      assert tx.double_spent
      assert tx.confirmed_height == 0
    end
  end
end
