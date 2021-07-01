defmodule BitPal.InvoiceTransactionsTest do
  use BitPal.IntegrationCase
  alias BitPal.Blocks
  alias BitPalSchemas.TxOutput

  setup do
    assert {:ok, invoice} =
             Invoices.register(%{
               amount: Money.parse!(1.2, "BCH"),
               exchange_rate: ExchangeRate.new!(Decimal.from_float(2.0), {"BCH", "USD"}),
               required_confirmations: 5
             })

    assert {:ok, address} = Addresses.register_next_address(:BCH, "bch:0")
    assert {:ok, invoice} = Invoices.assign_address(invoice, address)

    %{invoice: invoice, address: address}
  end

  test "invoice assoc", %{invoice: invoice, address: address} do
    assert :ok = Transactions.confirmed("tx:0", [{address.id, Money.new(1_000, :BCH)}], 0)
    assert :ok = Transactions.confirmed("tx:1", [{address.id, Money.new(2_000, :BCH)}], 1)

    tx0 = Repo.get_by!(TxOutput, txid: "tx:0") |> Repo.preload(:invoice)
    tx1 = Repo.get_by!(TxOutput, txid: "tx:1") |> Repo.preload(:invoice)

    assert tx0.invoice.id == tx1.invoice.id
    assert tx0.invoice.id == invoice.id

    invoice = invoice |> Repo.preload(:tx_outputs)
    assert Enum.count(invoice.tx_outputs) == 2
  end

  test "amount paid calculation", %{invoice: invoice, address: address} do
    assert :ok = Transactions.confirmed("tx:0", [{address.id, Money.parse!(0.4, :BCH)}], 0)
    invoice = Invoices.update_amount_paid(invoice)
    assert invoice.amount_paid == Money.parse!(0.4, :BCH)
    assert :underpaid == Invoices.target_amount_reached?(invoice)

    assert :ok = Transactions.confirmed("tx:1", [{address.id, Money.parse!(0.8, :BCH)}], 1)
    invoice = Invoices.update_amount_paid(invoice)
    assert invoice.amount_paid == Money.parse!(1.2, :BCH)
    assert :ok == Invoices.target_amount_reached?(invoice)

    assert :ok = Transactions.confirmed("tx:2", [{address.id, Money.parse!(0.5, :BCH)}], 2)
    invoice = Invoices.update_amount_paid(invoice)
    assert invoice.amount_paid == Money.parse!(1.7, :BCH)
    assert :overpaid == Invoices.target_amount_reached?(invoice)
  end

  test "confirmations until paid", %{invoice: invoice, address: address} do
    assert 5 == Invoices.confirmations_until_paid(invoice)

    Blocks.set_block_height(:BCH, 0)

    assert :ok = Transactions.seen("tx:0", [{address.id, Money.parse!(0.2, :BCH)}])
    assert 5 == Invoices.confirmations_until_paid(invoice)

    Transactions.confirmed("tx:0", [{address.id, Money.parse!(0.2, :BCH)}], 0)
    assert 4 == Invoices.confirmations_until_paid(invoice)

    Blocks.new_block(:BCH, 1)
    assert 3 == Invoices.confirmations_until_paid(invoice)

    assert :ok = Transactions.confirmed("tx:1", [{address.id, Money.parse!(0.2, :BCH)}], 1)
    assert 4 == Invoices.confirmations_until_paid(invoice)

    Blocks.new_block(:BCH, 2)
    assert 3 == Invoices.confirmations_until_paid(invoice)
    Blocks.new_block(:BCH, 3)
    Blocks.new_block(:BCH, 4)
    Blocks.new_block(:BCH, 5)
    assert 0 == Invoices.confirmations_until_paid(invoice)
    Blocks.new_block(:BCH, 6)
    assert 0 == Invoices.confirmations_until_paid(invoice)
  end
end
