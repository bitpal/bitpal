defmodule BitPal.InvoiceTransactionsTest do
  use BitPal.DataCase, async: true
  import TransactionFixtures
  alias BitPal.Blocks
  alias BitPalSchemas.TxOutput

  setup tags do
    currency_id = CurrencyFixtures.unique_currency_id()

    invoice =
      Map.take(tags, [:amount, :required_confirmations])
      |> Map.merge(%{
        address: :auto,
        currency_id: currency_id
      })
      |> InvoiceFixtures.invoice_fixture()

    %{invoice: invoice, address: invoice.address, currency_id: currency_id}
  end

  test "invoice assoc", %{invoice: invoice, address: address, currency_id: currency_id} do
    txid0 = unique_txid()
    txid1 = unique_txid()

    assert :ok = Transactions.confirmed(txid0, [{address.id, Money.new(1_000, currency_id)}], 0)
    assert :ok = Transactions.confirmed(txid1, [{address.id, Money.new(2_000, currency_id)}], 1)

    tx0 = Repo.get_by!(TxOutput, txid: txid0) |> Repo.preload(:invoice)
    tx1 = Repo.get_by!(TxOutput, txid: txid1) |> Repo.preload(:invoice)

    assert tx0.invoice.id == tx1.invoice.id
    assert tx0.invoice.id == invoice.id

    invoice = invoice |> Repo.preload(:tx_outputs)
    assert Enum.count(invoice.tx_outputs) == 2
  end

  @tag amount: 1.2
  test "amount paid calculation", %{invoice: invoice, address: address, currency_id: currency_id} do
    assert :ok =
             Transactions.confirmed(
               unique_txid(),
               [{address.id, Money.parse!(0.4, currency_id)}],
               0
             )

    invoice = Invoices.update_info_from_txs(invoice, nil)
    assert invoice.amount_paid == Money.parse!(0.4, currency_id)
    assert :underpaid == Invoices.target_amount_reached?(invoice)

    assert :ok =
             Transactions.confirmed(
               unique_txid(),
               [{address.id, Money.parse!(0.8, currency_id)}],
               1
             )

    invoice = Invoices.update_info_from_txs(invoice, nil)
    assert invoice.amount_paid == Money.parse!(1.2, currency_id)
    assert :ok == Invoices.target_amount_reached?(invoice)

    assert :ok =
             Transactions.confirmed(
               unique_txid(),
               [{address.id, Money.parse!(0.5, currency_id)}],
               2
             )

    invoice = Invoices.update_info_from_txs(invoice, nil)
    assert invoice.amount_paid == Money.parse!(1.7, currency_id)
    assert :overpaid == Invoices.target_amount_reached?(invoice)
  end

  @tag required_confirmations: 5
  test "confirmations until paid", %{invoice: invoice, address: address, currency_id: currency_id} do
    txid0 = unique_txid()
    txid1 = unique_txid()

    assert 5 == Invoices.confirmations_until_paid(invoice)

    Blocks.set_block_height(currency_id, 0)

    assert :ok = Transactions.seen(txid0, [{address.id, Money.parse!(0.2, currency_id)}])
    assert 5 == Invoices.confirmations_until_paid(invoice)

    Transactions.confirmed(txid0, [{address.id, Money.parse!(0.2, currency_id)}], 0)
    assert 4 == Invoices.confirmations_until_paid(invoice)

    Blocks.new_block(currency_id, 1)
    assert 3 == Invoices.confirmations_until_paid(invoice)

    assert :ok = Transactions.confirmed(txid1, [{address.id, Money.parse!(0.2, currency_id)}], 1)
    assert 4 == Invoices.confirmations_until_paid(invoice)

    Blocks.new_block(currency_id, 2)
    assert 3 == Invoices.confirmations_until_paid(invoice)
    Blocks.new_block(currency_id, 3)
    Blocks.new_block(currency_id, 4)
    Blocks.new_block(currency_id, 5)
    assert 0 == Invoices.confirmations_until_paid(invoice)
    Blocks.new_block(currency_id, 6)
    assert 0 == Invoices.confirmations_until_paid(invoice)
  end
end
