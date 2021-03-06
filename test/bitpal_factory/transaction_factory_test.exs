defmodule BitPalFactory.TransactionFactoryTest do
  use BitPal.DataCase, async: true

  describe "unique_txid/0" do
    test "generate txs" do
      Enum.reduce(0..10, MapSet.new(), fn _, seen ->
        txid = unique_txid()
        assert !MapSet.member?(seen, txid), "Duplicate txid generated #{txid} #{inspect(seen)}"
        MapSet.put(seen, txid)
      end)
    end
  end

  describe "create_tx" do
    test "creation" do
      invoice = create_invoice()

      attrs = %{
        txid: "my-id",
        double_spent: true,
        confirmed_height: 1337
      }

      tx = create_tx(invoice, attrs)

      for {key, val} <- attrs do
        assert Map.fetch!(tx, key) == val, "#{key} not updated"
      end
    end

    test "assoc address" do
      address = create_address()
      tx = create_tx(address)
      assert tx.address_id == address.id
    end

    test "assoc invoice" do
      invoice = create_invoice()

      tx =
        create_tx(invoice)
        |> Repo.preload(:invoice)

      assert tx.invoice.id == invoice.id
    end
  end

  describe "with_txs/2" do
    setup tags do
      invoices =
        Stream.repeatedly(fn ->
          create_invoice(tags)
          |> with_txs(tx_count: tags[:tx_count])
        end)
        |> Enum.take(tags[:count] || 3)

      Map.put(tags, :invoices, invoices)
    end

    @tag status: :draft
    test "draft", %{invoices: invoices} do
      for invoice <- invoices do
        invoice = invoice |> Repo.preload(:tx_outputs, force: true)

        # No txs allowed for drafts
        assert Enum.empty?(invoice.tx_outputs)
        assert invoice.address_id == nil
      end
    end

    @tag status: :open, tx_count: 1
    test "open invoice", %{invoices: invoices} do
      for invoice <- invoices do
        assert is_binary(invoice.address_id)
        assert Enum.count(invoice.tx_outputs) == 1
        assert invoice.amount_paid != nil
        assert Invoices.target_amount_reached?(invoice) == :underpaid
        assert is_integer(invoice.confirmations_due)
      end
    end

    @tag status: :processing, required_confirmations: 0
    test "processing invoice with 0-conf", %{invoices: invoices} do
      for invoice <- invoices do
        assert is_binary(invoice.address_id)
        assert invoice.required_confirmations == 0
        assert Enum.any?(invoice.tx_outputs)
        assert invoice.status_reason == :verifying
        assert Invoices.target_amount_reached?(invoice) in [:overpaid, :ok]
      end
    end

    @tag status: :processing, required_confirmations: 2
    test "processing invoice with confs", %{invoices: invoices} do
      for invoice <- invoices do
        assert is_binary(invoice.address_id)
        assert invoice.required_confirmations == 2
        assert Enum.any?(invoice.tx_outputs)
        assert invoice.status_reason == :confirming
        assert Invoices.target_amount_reached?(invoice) in [:overpaid, :ok]
      end
    end

    @tag status: :uncollectible, status_reason: :expired
    test "uncollectible expired invoice", %{invoices: invoices} do
      for invoice <- invoices do
        assert is_binary(invoice.address_id)
        assert invoice.status_reason == :expired
        assert Enum.empty?(invoice.tx_outputs)
      end
    end

    @tag status: :uncollectible, status_reason: :canceled
    test "uncollectible canceled invoice", %{invoices: invoices} do
      for invoice <- invoices do
        assert is_binary(invoice.address_id)
        assert invoice.status_reason == :canceled
        assert Enum.empty?(invoice.tx_outputs)
      end
    end

    @tag status: :uncollectible, status_reason: :timed_out, required_confirmations: 1
    test "uncollectible timed_out invoice", %{invoices: invoices} do
      for invoice <- invoices do
        assert is_binary(invoice.address_id)
        assert invoice.status_reason == :timed_out
        assert Enum.any?(invoice.tx_outputs)
        assert Invoices.target_amount_reached?(invoice) == :ok
        assert invoice.confirmations_due == 1
      end
    end

    @tag status: :uncollectible, status_reason: :double_spent
    test "uncollectible invoice", %{invoices: invoices} do
      for invoice <- invoices do
        assert is_binary(invoice.address_id)
        assert invoice.status_reason == :double_spent
        [tx] = invoice.tx_outputs
        assert tx.double_spent
        assert Invoices.target_amount_reached?(invoice) == :ok
      end
    end

    @tag status: :void
    test "void invoice", %{invoices: invoices} do
      for invoice <- invoices do
        assert is_binary(invoice.address_id)
        assert invoice.status_reason in [:expired, :canceled, :double_spent, :timed_out, nil]
      end
    end

    @tag status: :paid, count: 1
    test "paid invoice", %{invoices: invoices} do
      for invoice <- invoices do
        assert is_binary(invoice.address_id)
        assert invoice.status_reason == nil
        assert invoice.confirmations_due == 0
        assert Enum.count(invoice.tx_outputs) > 0
        assert Invoices.target_amount_reached?(invoice) in [:overpaid, :ok]
      end
    end
  end
end
