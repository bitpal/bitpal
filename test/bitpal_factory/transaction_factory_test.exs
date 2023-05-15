defmodule BitPalFactory.TransactionFactoryTest do
  use BitPal.DataCase, async: true
  alias BitPalSchemas.InvoiceStatus

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
        double_spent: true,
        failed: true,
        height: 1337
      }

      tx = create_tx(invoice, Map.put(attrs, :txid, "my-id"))

      assert tx.id == "my-id"

      for {key, val} <- attrs do
        assert Map.fetch!(tx, key) == val, "#{key} not updated"
      end
    end

    test "assoc address" do
      address = create_address()
      tx = create_tx(address)
      output = hd(tx.outputs) |> Repo.preload(:invoice)
      assert output.address_id == address.id
    end

    test "assoc invoice" do
      invoice = create_invoice()
      tx = create_tx(invoice)
      output = hd(tx.outputs) |> Repo.preload(:invoice)
      assert output.invoice.id == invoice.id
    end
  end

  describe "with_txs/2" do
    setup tags do
      invoices =
        Stream.repeatedly(fn ->
          create_invoice(tags)
          |> with_txs(tx_count: tags[:tx_count])
          |> Repo.preload([:tx_outputs, :transactions])
        end)
        |> Enum.take(tags[:count] || 3)

      Map.put(tags, :invoices, invoices)
    end

    @tag status: :draft
    test "draft", %{invoices: invoices} do
      for invoice <- invoices do
        # No txs allowed for drafts
        assert Enum.empty?(invoice.tx_outputs)
        assert invoice.address_id == nil
      end
    end

    @tag status: :open, tx_count: 1
    test "open invoice", %{invoices: invoices} do
      for invoice <- invoices do
        assert is_binary(invoice.address_id)
        assert Enum.count(invoice.transactions) == 1
        assert Enum.count(invoice.tx_outputs) == 1
        assert invoice.amount_paid != nil
        assert Invoices.target_amount_reached?(invoice) == :underpaid
        assert is_integer(invoice.confirmations_due)
      end
    end

    @tag status: {:processing, :verifying}, required_confirmations: 0
    test "processing invoice with 0-conf", %{invoices: invoices} do
      for invoice <- invoices do
        assert is_binary(invoice.address_id)
        assert invoice.required_confirmations == 0
        assert Enum.any?(invoice.tx_outputs)
        assert InvoiceStatus.reason(invoice.status) == :verifying
        assert Invoices.target_amount_reached?(invoice) in [:overpaid, :ok]
      end
    end

    @tag status: {:processing, :confirming}, required_confirmations: 2
    test "processing invoice with confs", %{invoices: invoices} do
      for invoice <- invoices do
        assert is_binary(invoice.address_id)
        assert invoice.required_confirmations == 2
        assert Enum.any?(invoice.tx_outputs)
        assert InvoiceStatus.reason(invoice.status) == :confirming
        assert Invoices.target_amount_reached?(invoice) in [:overpaid, :ok]
      end
    end

    @tag status: {:uncollectible, :expired}
    test "uncollectible expired invoice", %{invoices: invoices} do
      for invoice <- invoices do
        assert is_binary(invoice.address_id)
        assert InvoiceStatus.reason(invoice.status) == :expired
        assert Enum.empty?(invoice.tx_outputs)
      end
    end

    @tag status: {:uncollectible, :canceled}
    test "uncollectible canceled invoice", %{invoices: invoices} do
      for invoice <- invoices do
        assert is_binary(invoice.address_id)
        assert InvoiceStatus.reason(invoice.status) == :canceled
        assert Enum.empty?(invoice.tx_outputs)
      end
    end

    @tag status: {:uncollectible, :timed_out}, required_confirmations: 1
    test "uncollectible timed_out invoice", %{invoices: invoices} do
      for invoice <- invoices do
        assert is_binary(invoice.address_id)
        assert InvoiceStatus.reason(invoice.status) == :timed_out
        assert Enum.any?(invoice.tx_outputs)
        assert Invoices.target_amount_reached?(invoice) == :ok
        assert invoice.confirmations_due == 1
      end
    end

    @tag status: {:uncollectible, :double_spent}
    test "uncollectible invoice", %{invoices: invoices} do
      for invoice <- invoices do
        assert is_binary(invoice.address_id)
        assert InvoiceStatus.reason(invoice.status) == :double_spent
        [tx] = invoice.transactions
        assert tx.double_spent
        assert Invoices.target_amount_reached?(invoice) == :ok
      end
    end

    @tag status: :void
    test "void invoice", %{invoices: invoices} do
      for invoice <- invoices do
        assert is_binary(invoice.address_id)

        assert InvoiceStatus.reason(invoice.status) in [
                 :expired,
                 :canceled,
                 :double_spent,
                 :timed_out,
                 nil
               ]
      end
    end

    @tag status: :paid, count: 1
    test "paid invoice", %{invoices: invoices} do
      for invoice <- invoices do
        assert is_binary(invoice.address_id)
        assert InvoiceStatus.reason(invoice.status) == nil
        assert Enum.count(invoice.tx_outputs) > 0
        assert Invoices.target_amount_reached?(invoice) in [:overpaid, :ok]
      end
    end
  end
end
