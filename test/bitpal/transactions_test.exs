defmodule BitPal.TransactionsTest do
  use BitPal.IntegrationCase, async: true
  alias BitPalSchemas.TxOutput

  test "seen" do
    assert {:ok, address} = Addresses.register(:BCH, "bch:0", 0)

    assert :ok = Transactions.seen("tx:0", [{address.id, Money.new(1_000, :BCH)}])
    tx = Repo.get_by!(TxOutput, txid: "tx:0")
    assert tx.txid == "tx:0"
    assert tx.address_id == "bch:0"
    assert tx.confirmed_height == nil
  end

  test "2x output seen" do
    assert {:ok, address} = Addresses.register(:BCH, "bch:0", 0)

    assert :ok =
             Transactions.seen("tx:0", [
               {address.id, Money.new(1_000, :BCH)},
               {address.id, Money.new(2_000, :BCH)}
             ])

    txs = Repo.all(TxOutput)

    assert Enum.count(txs) == 2

    Enum.each(txs, fn tx ->
      assert tx.txid == "tx:0"
      assert tx.address_id == "bch:0"
      assert tx.confirmed_height == nil
    end)
  end

  test "2x output seen separate addresses" do
    assert {:ok, address0} = Addresses.register_next_address(:BCH, "bch:0")
    assert {:ok, address1} = Addresses.register_next_address(:BCH, "bch:1")

    assert :ok =
             Transactions.seen("txid", [
               {address0.id, Money.new(1_000, :BCH)},
               {address1.id, Money.new(2_000, :BCH)}
             ])

    tx0 = Repo.get_by!(TxOutput, txid: "txid", address_id: "bch:0")
    assert tx0.txid == "txid"
    assert tx0.address_id == "bch:0"
    assert tx0.confirmed_height == nil

    tx1 = Repo.get_by!(TxOutput, txid: "txid", address_id: "bch:1")
    assert tx1.txid == "txid"
    assert tx1.address_id == "bch:1"
    assert tx1.confirmed_height == nil
  end

  test "confirmed" do
    assert {:ok, address} = Addresses.register(:BCH, "bch:0", 0)

    assert :ok = Transactions.confirmed("tx:0", [{address.id, Money.new(1_000, :BCH)}], 0)
    tx = Repo.get_by!(TxOutput, txid: "tx:0")
    assert tx.txid == "tx:0"
    assert tx.address_id == "bch:0"
    assert tx.confirmed_height == 0
  end

  test "2x output confirmed separate addresses" do
    assert {:ok, address0} = Addresses.register_next_address(:BCH, "bch:0")
    assert {:ok, address1} = Addresses.register_next_address(:BCH, "bch:1")

    assert :ok =
             Transactions.seen("txid", [
               {address0.id, Money.new(1_000, :BCH)},
               {address1.id, Money.new(2_000, :BCH)}
             ])

    assert :ok =
             Transactions.confirmed(
               "txid",
               [
                 {address0.id, Money.new(1_000, :BCH)},
                 {address1.id, Money.new(2_000, :BCH)}
               ],
               1
             )

    tx0 = Repo.get_by!(TxOutput, txid: "txid", address_id: "bch:0")
    assert tx0.txid == "txid"
    assert tx0.address_id == "bch:0"
    assert tx0.confirmed_height == 1

    tx1 = Repo.get_by!(TxOutput, txid: "txid", address_id: "bch:1")
    assert tx1.txid == "txid"
    assert tx1.address_id == "bch:1"
    assert tx1.confirmed_height == 1
  end

  test "seen then confirmed" do
    assert {:ok, address} = Addresses.register(:BCH, "bch:0", 0)

    assert :ok = Transactions.seen("tx:0", [{address.id, Money.new(1_000, :BCH)}])
    tx = Repo.get_by!(TxOutput, txid: "tx:0")
    assert tx.confirmed_height == nil

    assert :ok = Transactions.confirmed("tx:0", [{address.id, Money.new(1_000, :BCH)}], 1)
    tx2 = Repo.get_by!(TxOutput, txid: "tx:0")
    assert tx.id == tx2.id
    assert tx2.confirmed_height == 1
  end

  test "reversed" do
    assert {:ok, address} = Addresses.register(:BCH, "bch:0", 0)

    assert :ok = Transactions.confirmed("tx:0", [{address.id, Money.new(1_000, :BCH)}], 0)
    tx = Repo.get_by!(TxOutput, txid: "tx:0")
    assert tx.confirmed_height == 0

    assert :ok = Transactions.reversed("tx:0", [{address.id, Money.new(1_000, :BCH)}])
    tx = Repo.get_by!(TxOutput, txid: "tx:0")
    assert tx.confirmed_height == nil
    assert !tx.double_spent
  end

  test "0-conf double spent" do
    assert {:ok, address} = Addresses.register(:BCH, "bch:0", 0)

    assert :ok = Transactions.seen("tx:0", [{address.id, Money.new(1_000, :BCH)}])
    tx = Repo.get_by!(TxOutput, txid: "tx:0")
    assert !tx.double_spent

    assert :ok = Transactions.double_spent("tx:0", [{address.id, Money.new(1_000, :BCH)}])
    tx = Repo.get_by!(TxOutput, txid: "tx:0")
    assert tx.double_spent
  end

  test "failed delayed double spend attempt" do
    # It's possible to mark a transaction as both a double spend and as having a confirmation.
    # This means that the double spend attempt failed.
    assert {:ok, address} = Addresses.register(:BCH, "bch:0", 0)

    assert :ok = Transactions.confirmed("tx:0", [{address.id, Money.new(1_000, :BCH)}], 0)
    tx = Repo.get_by!(TxOutput, txid: "tx:0")
    assert !tx.double_spent
    assert tx.confirmed_height == 0

    assert :ok = Transactions.double_spent("tx:0", [{address.id, Money.new(1_000, :BCH)}])
    tx = Repo.get_by!(TxOutput, txid: "tx:0")
    assert tx.double_spent
    assert tx.confirmed_height == 0
  end
end
