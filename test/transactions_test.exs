defmodule BitPal.TransactionsTest do
  use BitPal.IntegrationCase, async: true

  test "seen" do
    assert {:ok, address} = Addresses.register(:BCH, "bch:0", 0)
    assert {:ok, tx} = Transactions.seen("tx:0", address.id, Money.new(1_000, :BCH))
    tx = Repo.preload(tx, :address)

    assert tx.id == "tx:0"
    assert tx.address_id == "bch:0"
    assert tx.address != nil
    assert tx.confirmed_height == nil
  end

  test "seen x2" do
    assert {:ok, address} = Addresses.register(:BCH, "bch:0", 0)
    assert {:ok, tx} = Transactions.seen("tx:0", address.id, Money.new(1_000, :BCH))
    assert tx.id == "tx:0"

    assert {:ok, tx} = Transactions.seen("tx:0", address.id, Money.new(1_000, :BCH))
    assert tx.id == "tx:0"
  end

  test "confirmed" do
    assert {:ok, address} = Addresses.register(:BCH, "bch:0", 0)
    assert {:ok, tx} = Transactions.confirmed("tx:0", address.id, Money.new(1_000, :BCH), 0)
    tx = Repo.preload(tx, :address)

    assert tx.id == "tx:0"
    assert tx.address_id == "bch:0"
    assert tx.address != nil
    assert tx.confirmed_height == 0
  end

  test "seen then confirmed" do
    assert {:ok, address} = Addresses.register(:BCH, "bch:0", 0)
    assert {:ok, tx} = Transactions.seen("tx:0", address.id, Money.new(1_000, :BCH))

    assert tx.confirmed_height == nil

    assert {:ok, tx} = Transactions.confirmed("tx:0", address.id, Money.new(1_000, :BCH), 1)
    assert tx.confirmed_height == 1
  end

  test "reversed" do
    assert {:ok, address} = Addresses.register(:BCH, "bch:0", 0)
    assert {:ok, tx} = Transactions.confirmed("tx:0", address.id, Money.new(1_000, :BCH), 0)
    assert tx.confirmed_height == 0
    assert {:ok, tx} = Transactions.reversed("tx:0", address.id, Money.new(1_000, :BCH), 0)
    assert tx.confirmed_height == nil
    assert tx.double_spent == false
  end

  test "0-conf double spent" do
    assert {:ok, address} = Addresses.register(:BCH, "bch:0", 0)
    assert {:ok, tx} = Transactions.seen("tx:0", address.id, Money.new(1_000, :BCH))
    assert tx.double_spent == false
    assert {:ok, tx} = Transactions.double_spent("tx:0", address.id, Money.new(1_000, :BCH))
    assert tx.double_spent == true
  end

  test "failed delayed double spend attempt" do
    # It's possible to mark a transaction as both a double spend and as having a confirmation.
    # This means that the double spend attempt failed.
    assert {:ok, address} = Addresses.register(:BCH, "bch:0", 0)
    assert {:ok, tx} = Transactions.confirmed("tx:0", address.id, Money.new(1_000, :BCH), 0)
    assert tx.double_spent == false
    assert tx.confirmed_height == 0
    assert {:ok, tx} = Transactions.double_spent("tx:0", address.id, Money.new(1_000, :BCH))
    assert tx.double_spent == true
    assert tx.confirmed_height == 0
  end
end
