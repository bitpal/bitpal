defmodule BitPal.InvoiceTransactionsTest do
  use BitPal.IntegrationCase

  setup do
    assert {:ok, invoice} =
             Invoices.register(%{
               amount: Money.parse!(1.2, "BCH"),
               exchange_rate: ExchangeRate.new!(Decimal.from_float(2.0), {"BCH", "USD"})
             })

    %{invoice: invoice}
  end

  test "invoice assoc", %{invoice: invoice} do
    assert {:ok, address} = Addresses.register_next_address(:BCH, "bch:0")
    assert {:ok, invoice} = Invoices.assign_address(invoice, address)

    assert {:ok, tx0} = Transactions.confirmed("tx:0", address.id, Money.new(1_000, :BCH), 0)
    assert {:ok, tx1} = Transactions.confirmed("tx:1", address.id, Money.new(2_000, :BCH), 1)

    tx0 = tx0 |> Repo.preload(:invoice)
    tx1 = tx1 |> Repo.preload(:invoice)
    assert tx0.invoice.id == tx1.invoice.id
    assert tx0.invoice.id == invoice.id

    invoice = invoice |> Repo.preload(:transactions)
    assert Enum.count(invoice.transactions) == 2
  end

  test "amount paid calculation", %{invoice: invoice} do
    assert {:ok, address} = Addresses.register_next_address(:BCH, "bch:0")
    assert {:ok, invoice} = Invoices.assign_address(invoice, address)

    assert {:ok, _} = Transactions.confirmed("tx:0", address.id, Money.parse!(0.4, :BCH), 0)
    invoice = Invoices.update_amount_paid(invoice)
    assert invoice.amount_paid == Money.parse!(0.4, :BCH)
    assert :underpaid == Invoices.target_amount_reached?(invoice)

    assert {:ok, _} = Transactions.confirmed("tx:1", address.id, Money.parse!(0.8, :BCH), 1)
    invoice = Invoices.update_amount_paid(invoice)
    assert invoice.amount_paid == Money.parse!(1.2, :BCH)
    assert :ok == Invoices.target_amount_reached?(invoice)

    assert {:ok, _} = Transactions.confirmed("tx:2", address.id, Money.parse!(0.5, :BCH), 2)
    invoice = Invoices.update_amount_paid(invoice)
    assert invoice.amount_paid == Money.parse!(1.7, :BCH)
    assert :overpaid == Invoices.target_amount_reached?(invoice)
  end
end
