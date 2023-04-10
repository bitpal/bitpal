defmodule BitPalApi.InvoiceChannelTest do
  use BitPalApi.ChannelCase, async: true, integration: true
  alias BitPalFactory.InvoiceFactory
  alias BitPal.BackendMock
  alias BitPal.HandlerSubscriberCollector

  describe "invoice notifications" do
    setup [:setup_open]

    @tag double_spend_timeout: 1
    test "0-conf acceptance", %{invoice: invoice} do
      txid = BackendMock.tx_seen(invoice)
      id = invoice.id

      assert_broadcast("processing", %{
        id: ^id,
        statusReason: :verifying,
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
        statusReason: :confirming,
        confirmations_due: 3,
        txs: [%{amount: _, txid: ^txid}]
      })

      BackendMock.confirmed_in_new_block(invoice)

      assert_broadcast("processing", %{
        id: ^id,
        statusReason: :confirming,
        confirmations_due: 2
      })

      BackendMock.issue_blocks(invoice, 2)

      assert_broadcast("processing", %{
        id: ^id,
        statusReason: :confirming,
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
        statusReason: :verifying,
        txs: _
      })

      assert_broadcast("uncollectible", %{id: ^id, statusReason: :double_spent})
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
        statusReason: :verifying,
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

  # Invoice channel and invoice controller use the same internals,
  # so we don't have to replicate all tests here.
  describe "draft actions" do
    setup [:setup_draft]

    test "get invoice", %{socket: socket, invoice: invoice} do
      id = invoice.id
      ref = push(socket, "get", %{})

      assert_reply(ref, :ok, %{
        id: ^id,
        status: :draft
      })
    end

    test "delete", %{socket: socket, invoice: invoice} do
      ref = push(socket, "delete", %{})
      id = invoice.id

      assert_reply(ref, :ok, %{})
      assert_broadcast("deleted", %{id: ^id, deleted: true})
    end

    test "update", %{socket: socket, invoice: invoice} do
      ref =
        push(socket, "update", %{
          price: 7.0,
          priceCurrency: "EUR",
          paymentCurrency: "XMR",
          description: "My awesome invoice",
          email: "test@bitpal.dev",
          orderId: "id:123",
          posData: %{
            "some" => "data",
            "other" => %{"even_more" => 0.1337}
          }
        })

      id = invoice.id

      assert_reply(ref, :ok, %{
        id: ^id
      })
    end

    test "cannot mark as paid", %{socket: socket} do
      ref = push(socket, "pay", %{})

      assert_reply(ref, :error, %{
        code: "invalid_transition",
        message: "invalid transition from `draft` to `paid`",
        type: "invalid_request_error"
      })
    end

    test "cannot void", %{socket: socket} do
      ref = push(socket, "void", %{})

      assert_reply(ref, :error, %{
        code: "invalid_transition",
        message: "invalid transition from `draft` to `void`",
        type: "invalid_request_error"
      })
    end
  end

  describe "open invoice actions" do
    setup [:setup_open]

    test "cannot delete a finalized invoice", %{socket: socket} do
      ref = push(socket, "delete", %{})

      assert_reply(ref, :error, %{
        code: "invoice_not_editable",
        message: "cannot delete a finalized invoice",
        type: "invalid_request_error"
      })
    end

    test "void", %{socket: socket, invoice: invoice} do
      ref = push(socket, "void", %{})
      id = invoice.id

      assert_reply(ref, :ok, %{})

      assert_broadcast("voided", %{
        id: ^id,
        status: :void
      })
    end
  end

  describe "uncollectible actions" do
    setup [:setup_uncollectable]

    test "void", %{socket: socket, invoice: invoice} do
      ref = push(socket, "void", %{})
      id = invoice.id

      assert_reply(ref, :ok, %{})

      assert_broadcast("voided", %{
        id: ^id,
        status: :void,
        statusReason: :canceled
      })
    end

    test "pay", %{socket: socket, invoice: invoice} do
      ref = push(socket, "pay", %{})
      id = invoice.id

      assert_reply(ref, :ok, %{})

      assert_broadcast("paid", %{
        id: ^id,
        status: :paid
      })
    end
  end

  defp setup_draft(context) do
    setup_invoice(context, status: :draft)
  end

  defp setup_open(context) do
    setup_invoice(context,
      address_id: :auto,
      status: :open
    )
  end

  defp setup_uncollectable(context) do
    setup_invoice(context,
      address_id: :auto,
      status: {:uncollectible, :canceled}
    )
  end

  defp setup_invoice(context, attrs) do
    invoice_attrs =
      %{
        required_confirmations: 0,
        double_spend_timeout: 1_000,
        expected_payment:
          Money.parse!(context[:amount] || 0.3, Map.fetch!(context, :currency_id)),
        price: Money.parse!(1.0, :USD)
      }
      |> Map.merge(
        Map.take(context, [:payment_currency_id, :required_confirmations, :double_spend_timeout])
      )
      |> Map.merge(Map.new(attrs))

    invoice = init_invoice(invoice_attrs)

    # Bypasses socket `connect`, which is fine for these tests
    {:ok, _, socket} =
      BitPalApi.StoreSocket
      |> socket(nil, %{store_id: invoice.store_id})
      |> subscribe_and_join(BitPalApi.InvoiceChannel, "invoice:" <> invoice.id)

    %{invoice: invoice, socket: socket}
  end

  defp init_invoice(attrs = %{status: :open}) do
    {:ok, invoice, _stub, _invoice_handler} = HandlerSubscriberCollector.create_invoice(attrs)
    invoice
  end

  defp init_invoice(attrs) do
    InvoiceFactory.create_invoice(attrs)
  end
end
