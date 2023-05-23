defmodule BitPal.TransactionsTest do
  use BitPal.IntegrationCase, async: true
  alias BitPal.AddressEvents

  setup tags do
    %{}
    |> setup_address(tags)
    |> setup_tx(tags)
  end

  defp setup_address(res, tags) do
    address = create_address()

    res =
      Map.merge(
        res,
        %{
          address: address,
          address_id: address.id,
          currency_id: address.currency_id,
          txid: unique_txid(),
          amount: create_money(address.currency_id)
        }
      )

    AddressEvents.subscribe(address.id)

    if tags[:other_address] do
      other_address = create_address(currency_id: address.currency_id)

      AddressEvents.subscribe(other_address.id)

      res
      |> Map.put(:other_address, other_address)
      |> Map.put(:other_amount, create_money(address.currency_id))
    else
      res
    end
  end

  defp setup_tx(res, tags) do
    if params = tags[:tx] do
      res
      |> Map.put(:tx, create_tx(res.address, Map.put_new(params, :txid, res[:txid])))
    else
      res
    end
  end

  describe "insert new transaction" do
    test "creates output", %{address: address, txid: txid, amount: amount} do
      assert {:ok, tx} =
               Transactions.update(txid,
                 outputs: [{address.id, amount}]
               )

      [output] = tx.outputs

      output = Repo.preload(output, [:address, :invoice, :currency])
      address = Repo.preload(address, [:invoice])

      assert output.amount == amount
      assert output.address_id == address.id
      assert output.address != nil
      assert output.invoice.id == address.invoice.id
      assert output.currency.id == address.currency_id

      # Ensure that it was inserted
      assert {:ok, _} = Transactions.fetch(txid)
    end

    test "regular unconfirmed", %{address: address, txid: txid, amount: amount} do
      assert {:ok, tx} =
               Transactions.update(txid,
                 outputs: [{address.id, amount}]
               )

      assert tx.height == 0

      assert_receive {{:tx, :pending}, %{id: ^txid}}
    end

    test "confirmed", %{address: address, txid: txid, amount: amount} do
      assert {:ok, tx} =
               Transactions.update(txid,
                 outputs: [{address.id, amount}],
                 height: 10
               )

      assert tx.height == 10

      assert_receive {{:tx, :confirmed}, %{id: ^txid, height: 10}}
    end

    test "double spend", %{address: address, txid: txid, amount: amount} do
      assert {:ok, _tx} =
               Transactions.update(txid,
                 outputs: [{address.id, amount}],
                 double_spent: true
               )

      assert_receive {{:tx, :double_spent}, %{id: ^txid}}
    end

    test "failed", %{address: address, txid: txid, amount: amount} do
      assert {:ok, _tx} =
               Transactions.update(txid,
                 outputs: [{address.id, amount}],
                 failed: true
               )

      assert_receive {{:tx, :failed}, %{id: ^txid}}
    end

    @tag other_address: true
    test "2x unconfirmed outputs", %{
      address: address,
      txid: txid,
      amount: amount,
      other_address: other_address,
      other_amount: other_amount
    } do
      assert {:ok, _tx} =
               Transactions.update(txid,
                 outputs: [{address.id, amount}, {other_address.id, other_amount}]
               )

      address1 = address.id
      address2 = other_address.id

      assert_receive {{:tx, :pending}, %{id: ^txid, address_id: ^address1}}
      assert_receive {{:tx, :pending}, %{id: ^txid, address_id: ^address2}}
    end

    test "2x outputs to separate addresses, not all are known to us", %{
      address: address,
      txid: txid,
      amount: amount
    } do
      other_address = "some-not-tracked"
      other_amount = create_money(address.currency_id)

      assert {:ok, _tx} =
               Transactions.update(txid,
                 outputs: [{address.id, amount}, {other_address, other_amount}]
               )

      address_id = address.id

      assert_receive {{:tx, :pending}, %{id: ^txid, address_id: ^address_id}}
      refute_receive {{:tx, :pending}, %{id: ^txid, address_id: ^other_address}}
    end

    test "invalid address", %{txid: txid, amount: amount} do
      assert {:error, :no_known_output} =
               Transactions.update(txid,
                 outputs: [{"xxx", amount}]
               )
    end

    test "no known address from multiple outputs", %{txid: txid, amount: amount} do
      assert {:error, :no_known_output} =
               Transactions.update(txid,
                 outputs: [{"xxx", amount}, {"yyy", amount}]
               )
    end

    test "invalid amount", %{txid: txid, address: address} do
      assert {:error, _} =
               Transactions.update(txid,
                 outputs: [{address.id, 2.1}]
               )
    end

    test "invalid currency in amount", %{txid: txid, address: address} do
      assert {:error, _} =
               Transactions.update(txid,
                 outputs: [{address.id, Money.new(100, :USD)}]
               )
    end

    test "missing outputs", %{txid: txid} do
      assert {:error, _} = Transactions.update(txid, [])
    end
  end

  describe "updates transaction" do
    @tag tx: %{height: 0}
    test "confirms an unconfirmed tx", %{tx: tx, txid: txid, address_id: address_id} do
      assert {:ok, _tx} = Transactions.update(tx.id, height: 20)
      assert_receive {{:tx, :confirmed}, %{id: ^txid, address_id: ^address_id, height: 20}}
    end

    @tag tx: %{height: 0}
    test "double spends an unconfirmed tx", %{tx: tx, txid: txid, address_id: address_id} do
      assert {:ok, _tx} = Transactions.update(tx.id, double_spent: true)
      assert_receive {{:tx, :double_spent}, %{id: ^txid, address_id: ^address_id}}
    end

    @tag tx: %{height: 0}
    test "fails an unconfirmed tx", %{tx: tx, txid: txid, address_id: address_id} do
      assert {:ok, _tx} = Transactions.update(tx.id, failed: true)
      assert_receive {{:tx, :failed}, %{id: ^txid, address_id: ^address_id}}
    end

    @tag tx: %{height: 5}
    test "reverses a confirmed tx", %{tx: tx, txid: txid, address_id: address_id} do
      assert {:ok, _tx} = Transactions.update(tx.id, height: 0)
      assert_receive {{:tx, :reversed}, %{id: ^txid, address_id: ^address_id}}
    end

    @tag tx: %{height: 5}
    test "fails a confirmed tx", %{tx: tx, txid: txid, address_id: address_id} do
      # Implies that it's also reversed
      assert {:ok, _tx} = Transactions.update(tx.id, height: 0, failed: true)
      assert_receive {{:tx, :failed}, %{id: ^txid, address_id: ^address_id}}
    end

    @tag tx: %{height: 5}
    test "double spends a confirmed tx", %{tx: tx, txid: txid, address_id: address_id} do
      # It means that a double spend attempt failed
      assert {:ok, _tx} = Transactions.update(tx.id, double_spent: true)
      assert_receive {{:tx, :double_spent}, %{id: ^txid, address_id: ^address_id}}
    end
  end

  describe "address_tx_info" do
    @tag other_address: true
    test "filter and sum outputs", %{address: address, other_address: other_address} do
      assert {:ok, _tx} =
               Transactions.update(unique_txid(),
                 outputs: [
                   {address.id, Money.new(100, address.currency_id)},
                   {other_address.id, Money.new(30, address.currency_id)}
                 ],
                 height: 1
               )

      assert {:ok, _tx} =
               Transactions.update(unique_txid(),
                 outputs: [
                   {address.id, Money.new(18, address.currency_id)},
                   {address.id, Money.new(2, address.currency_id)}
                 ],
                 height: 2
               )

      assert {:ok, _tx} =
               Transactions.update(unique_txid(),
                 outputs: [{other_address.id, Money.new(111, address.currency_id)}],
                 height: 3
               )

      m100 = Money.new(100, address.currency_id)
      m20 = Money.new(20, address.currency_id)

      assert [
               %{
                 txid: _,
                 height: 1,
                 failed: false,
                 double_spent: false,
                 amount: ^m100
               },
               %{
                 txid: _,
                 height: 2,
                 failed: false,
                 double_spent: false,
                 amount: ^m20
               }
             ] =
               Transactions.address_tx_info(address.id)
               |> Enum.sort_by(fn info -> info.height end)
    end
  end

  describe "active/1" do
    test "get active transactions", %{currency_id: currency_id} do
      _draft = create_invoice(payment_currency_id: currency_id, status: :draft)

      open =
        create_invoice(payment_currency_id: currency_id, status: :open, txs: :auto)
        |> Repo.preload(:transactions)

      processing =
        create_invoice(payment_currency_id: currency_id, status: :processing, txs: :auto)
        |> Repo.preload(:transactions)

      _paid = create_invoice(payment_currency_id: currency_id, status: :paid, txs: :auto)

      _double_spent =
        create_invoice(
          payment_currency_id: currency_id,
          status: {:uncollectible, :double_spent},
          txs: :auto
        )

      expected =
        (open.transactions ++ processing.transactions)
        |> MapSet.new(fn t -> t.id end)

      # At least one tx should exist in the processing invoice, and maybe some in the open invoice.
      assert Enum.any?(expected)

      active = Transactions.active(currency_id)

      assert Enum.count(expected) == Enum.count(active)

      for x <- active do
        assert MapSet.member?(expected, x.id)
      end
    end
  end
end
