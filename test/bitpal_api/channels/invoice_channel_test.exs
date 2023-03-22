defmodule BitPalApi.InvoiceChannelTest do
  use BitPalApi.ChannelCase, async: true, integration: true
  alias BitPal.BackendMock
  alias BitPal.HandlerSubscriberCollector

  describe "invoice notifications" do
    setup tags do
      {:ok, invoice, _stub, _invoice_handler} =
        HandlerSubscriberCollector.create_invoice(
          required_confirmations: tags[:required_confirmations] || 0,
          double_spend_timeout: tags[:double_spend_timeout] || 1_000,
          price: Money.parse!(1.0, :USD),
          expected_payment: Money.parse!(tags[:amount] || 0.3, Map.fetch!(tags, :currency_id))
        )

      # Bypasses socket `connect`, which is fine for these tests
      {:ok, _, socket} =
        BitPalApi.StoreSocket
        |> socket(nil, %{store_id: invoice.store_id})
        |> subscribe_and_join(BitPalApi.InvoiceChannel, "invoice:" <> invoice.id)

      %{invoice: invoice, socket: socket}
    end

    @tag double_spend_timeout: 1
    test "0-conf acceptance", %{invoice: invoice} do
      txid = BackendMock.tx_seen(invoice)
      id = invoice.id

      assert_broadcast("processing", %{
        id: ^id,
        reason: "verifying",
        txs: [%{amount: _, txid: ^txid}]
      })

      assert_broadcast("paid", %{id: ^id})
    end

    @tag required_confirmations: 3
    test "3-conf acceptance", %{invoice: invoice} do
      id = invoice.id
      txid = BackendMock.tx_seen(invoice)

      assert_broadcast("processing", %{
        id: ^id,
        reason: "confirming",
        confirmations_due: 3,
        txs: [%{amount: _, txid: ^txid}]
      })

      BackendMock.confirmed_in_new_block(invoice)

      assert_broadcast("processing", %{
        id: ^id,
        reason: "confirming",
        confirmations_due: 2
      })

      BackendMock.issue_blocks(invoice, 2)

      assert_broadcast("processing", %{
        id: ^id,
        reason: "confirming",
        confirmations_due: 1
      })

      assert_broadcast("paid", %{id: ^id})
    end

    @tag required_confirmations: 0
    test "Early 0-conf double spend", %{invoice: invoice} do
      id = invoice.id
      BackendMock.tx_seen(invoice)
      BackendMock.doublespend(invoice)

      assert_broadcast("processing", %{
        id: ^id,
        reason: "verifying",
        txs: _
      })

      assert_broadcast("uncollectible", %{id: ^id, reason: "double_spent"})
    end

    @tag double_spend_timeout: 1, required_confirmations: 0, amount: 1.0
    test "Under and overpaid invoice", %{invoice: invoice} do
      id = invoice.id

      BackendMock.tx_seen(%{
        invoice
        | expected_payment: Money.parse!(0.3, invoice.payment_currency_id)
      })

      assert_broadcast("underpaid", %{
        id: ^id,
        amount_due: due,
        txs: _
      })

      assert "0.700" <> _ = Decimal.to_string(due)

      BackendMock.tx_seen(%{
        invoice
        | expected_payment: Money.parse!(1.3, invoice.payment_currency_id)
      })

      assert_broadcast("overpaid", %{
        id: ^id,
        overpaid_amount: overpaid,
        txs: _
      })

      assert "0.600" <> _ = Decimal.to_string(overpaid)

      assert_broadcast("processing", %{
        id: ^id,
        reason: "verifying",
        txs: _
      })

      assert_broadcast("paid", %{id: ^id})
    end
  end

  describe "authorization" do
    test "unauthorized" do
      invoice = create_invoice()

      %{token: token} = create_auth()
      {:ok, socket} = connect(BitPalApi.StoreSocket, %{"token" => token}, %{})

      {:error, %{message: "Unauthorized", type: "api_connection_error"}} =
        subscribe_and_join(socket, "invoice:" <> invoice.id)
    end
  end
end
