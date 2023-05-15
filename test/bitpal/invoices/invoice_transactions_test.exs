defmodule BitPal.InvoiceTransactionsTest do
  use BitPal.DataCase, async: true
  alias BitPal.Blocks

  setup tags do
    currency_id = unique_currency_id()
    amount = Map.get(tags, :amount, rand_pos_float())
    expected_payment = Money.parse!(amount, currency_id)

    invoice =
      Map.take(tags, [:amount, :required_confirmations])
      |> Map.merge(%{
        address_id: :auto,
        expected_payment: expected_payment
      })
      |> create_invoice()

    %{invoice: invoice, address: invoice.address, currency_id: currency_id}
  end

  test "invoice assoc", %{invoice: invoice, address: address, currency_id: currency_id} do
    txid0 = unique_txid()
    txid1 = unique_txid()

    assert {:ok, tx0} =
             Transactions.update(txid0,
               outputs: [{address.id, Money.new(1_000, currency_id)}],
               height: 0
             )

    assert {:ok, tx1} =
             Transactions.update(txid1,
               outputs: [{address.id, Money.new(2_000, currency_id)}],
               height: 1
             )

    for out <- Repo.preload(tx0, :outputs).outputs do
      assert Repo.preload(out, :invoice).invoice.id == invoice.id
    end

    for out <- Repo.preload(tx1, :outputs).outputs do
      assert Repo.preload(out, :invoice).invoice.id == invoice.id
    end

    invoice = invoice |> Repo.preload(:tx_outputs)
    assert Enum.count(invoice.tx_outputs) == 2
  end

  describe "num_confirmations" do
    test "no confirmation", %{invoice: invoice, address: address, currency_id: currency_id} do
      Blocks.set_height(currency_id, 14)
      create_tx(address, height: 0)
      create_tx(address, height: 10)
      create_tx(address, height: 11)

      assert Invoices.num_confirmations(invoice) == 0
    end

    test "gets min", %{invoice: invoice, address: address, currency_id: currency_id} do
      Blocks.set_height(currency_id, 14)
      create_tx(address, height: 9)
      create_tx(address, height: 10)
      create_tx(address, height: 11)

      assert Invoices.num_confirmations(invoice) == 4
    end

    test "defaults to 0 if no txs", %{
      invoice: invoice,
      currency_id: currency_id
    } do
      Blocks.set_height(currency_id, 14)
      assert Invoices.num_confirmations(invoice) == 0
    end
  end

  @tag amount: 1.2
  test "amount paid calculation", %{invoice: invoice, address: address, currency_id: currency_id} do
    assert {:ok, _} =
             Transactions.update(
               unique_txid(),
               outputs: [{address.id, Money.parse!(0.4, currency_id)}],
               height: 0
             )

    invoice = Invoices.update_info_from_txs(invoice)
    assert invoice.amount_paid == Money.parse!(0.4, currency_id)
    assert :underpaid == Invoices.target_amount_reached?(invoice)

    assert {:ok, _} =
             Transactions.update(
               unique_txid(),
               outputs: [{address.id, Money.parse!(0.8, currency_id)}],
               height: 1
             )

    invoice = Invoices.update_info_from_txs(invoice)
    assert invoice.amount_paid == Money.parse!(1.2, currency_id)
    assert :ok == Invoices.target_amount_reached?(invoice)

    assert {:ok, _} =
             Transactions.update(
               unique_txid(),
               outputs: [{address.id, Money.parse!(0.5, currency_id)}],
               height: 2
             )

    invoice = Invoices.update_info_from_txs(invoice)
    assert invoice.amount_paid == Money.parse!(1.7, currency_id)
    assert :overpaid == Invoices.target_amount_reached?(invoice)
  end

  @tag required_confirmations: 5
  test "confirmations due", %{invoice: invoice, address: address, currency_id: currency_id} do
    txid0 = unique_txid()
    txid1 = unique_txid()

    assert 5 == Invoices.calculate_confirmations_due(invoice)

    Blocks.set_height(currency_id, 1)

    assert {:ok, _} =
             Transactions.update(txid0, outputs: [{address.id, Money.parse!(0.2, currency_id)}])

    assert 5 == Invoices.calculate_confirmations_due(invoice)

    Transactions.update(txid0, outputs: [{address.id, Money.parse!(0.2, currency_id)}], height: 1)
    assert 4 == Invoices.calculate_confirmations_due(invoice)

    Blocks.new_block(currency_id, 2)
    assert 3 == Invoices.calculate_confirmations_due(invoice)

    assert {:ok, _} =
             Transactions.update(txid1,
               outputs: [{address.id, Money.parse!(0.2, currency_id)}],
               height: 2
             )

    assert 4 == Invoices.calculate_confirmations_due(invoice)

    Blocks.new_block(currency_id, 3)
    assert 3 == Invoices.calculate_confirmations_due(invoice)
    Blocks.new_block(currency_id, 4)
    Blocks.new_block(currency_id, 5)
    Blocks.new_block(currency_id, 6)
    assert 0 == Invoices.calculate_confirmations_due(invoice)
    Blocks.new_block(currency_id, 7)
    assert 0 == Invoices.calculate_confirmations_due(invoice)
  end
end
