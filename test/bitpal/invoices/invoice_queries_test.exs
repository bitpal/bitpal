defmodule BitPal.InvoiceQueriesTest do
  use BitPal.DataCase, async: true

  describe "all_txs_below_height?" do
    setup tags do
      txs = Map.fetch!(tags, :txs)

      invoice =
        create_invoice(status: {:processing, :confirming}, required_confirmations: 5)
        |> with_txs(txs: Enum.map(txs, fn height -> %{height: height} end))

      %{txs: txs, invoice: invoice}
    end

    @tag txs: [11, 13]
    test "all above", %{invoice: invoice} do
      assert !Invoices.all_txs_below_height?(invoice, 10)
    end

    @tag txs: [3, 13]
    test "one below", %{invoice: invoice} do
      assert !Invoices.all_txs_below_height?(invoice, 10)
    end

    @tag txs: [3, 7]
    test "all below", %{invoice: invoice} do
      assert Invoices.all_txs_below_height?(invoice, 10)
    end

    @tag txs: [10]
    test "exactly on", %{invoice: invoice} do
      assert !Invoices.all_txs_below_height?(invoice, 10)
    end

    @tag txs: []
    test "no txs", %{invoice: invoice} do
      assert Invoices.all_txs_below_height?(invoice, 10)
    end
  end
end
