defmodule BitPalApi.InvoiceControllerTest do
  use BitPalApi.ConnCase, async: true, integration: true
  alias BitPal.BackendMock
  alias BitPal.ExchangeRates
  alias BitPal.Invoices
  alias BitPal.RenderHelpers
  alias BitPalSchemas.InvoiceRates

  describe "create" do
    test "standard fields", %{conn: conn} do
      conn =
        post(conn, "/api/v1/invoices", %{
          priceSubAmount: 120,
          priceCurrency: "USD",
          description: "My awesome invoice",
          email: "test@bitpal.dev",
          orderId: "id:123",
          posData: %{
            "some" => "data",
            "other" => %{"even_more" => 0.1337}
          }
        })

      assert %{
               "id" => id,
               "status" => "draft",
               "address" => nil,
               "description" => "My awesome invoice",
               "email" => "test@bitpal.dev",
               "orderId" => "id:123",
               "posData" => %{
                 "some" => "data",
                 "other" => %{"even_more" => 0.1337}
               }
             } = json_response(conn, 200)

      assert id != nil
      assert Invoices.fetch!(id).id == id
    end

    test "with fiat priceSubAmount", %{conn: conn} do
      conn =
        post(conn, "/api/v1/invoices", %{
          priceSubAmount: 120,
          priceCurrency: "USD"
        })

      assert %{
               "priceSubAmount" => 120,
               "priceCurrency" => "USD",
               "priceDisplay" => "$1.20",
               "rates" => rates
             } = json_response(conn, 200)

      assert rates != nil
      assert InvoiceRates.find_base_with_rate(rates, "USD") != :not_found
    end

    test "create with fiat price", %{conn: conn} do
      conn =
        post(conn, "/api/v1/invoices", %{
          price: "1.20",
          priceCurrency: "USD"
        })

      assert %{
               "price" => 1.2,
               "priceSubAmount" => 120,
               "priceCurrency" => "USD",
               "priceDisplay" => "$1.20",
               "rates" => rates
             } = json_response(conn, 200)

      assert rates != nil
      assert InvoiceRates.find_base_with_rate(rates, "USD") != :not_found
    end

    test "with crypto priceSubAmount", %{conn: conn} do
      conn =
        post(conn, "/api/v1/invoices", %{
          priceSubAmount: 1_200,
          priceCurrency: "BCH"
        })

      assert %{
               "price" => 0.000012,
               "priceSubAmount" => 1_200,
               "priceCurrency" => "BCH",
               "priceDisplay" => "0.000012 BCH",
               "paymentCurrency" => "BCH",
               "paymentSubAmount" => 1_200,
               "paymentDisplay" => "0.000012 BCH"
             } = json_response(conn, 200)
    end

    @tag do: true
    test "with crypto price", %{conn: conn} do
      conn =
        post(conn, "/api/v1/invoices", %{
          price: "1.2",
          priceCurrency: "BCH"
        })

      assert %{
               "price" => 1.2,
               "priceSubAmount" => 120_000_000,
               "priceCurrency" => "BCH",
               "priceDisplay" => "1.2 BCH",
               "paymentCurrency" => "BCH",
               "paymentSubAmount" => 120_000_000,
               "paymentDisplay" => "1.2 BCH"
             } = json_response(conn, 200)
    end

    test "create and finalize", %{conn: conn, currency_id: currency_id} do
      currency = Atom.to_string(currency_id)

      conn =
        post(conn, "/api/v1/invoices", %{
          price: "1.2",
          priceCurrency: "USD",
          paymentCurrency: currency,
          finalize: true
        })

      assert %{
               "id" => id,
               "address" => address,
               "price" => 1.2,
               "priceSubAmount" => 120,
               "priceCurrency" => "USD",
               "priceDisplay" => "$1.20",
               "paymentCurrency" => ^currency,
               "paymentSubAmount" => payment_sub_amount,
               "paymentDisplay" => payment_display,
               "requiredConfirmations" => 0,
               "rates" => %{
                 ^currency => %{"USD" => rate}
               },
               "status" => "open"
             } = json_response(conn, 200)

      assert id != nil
      assert address != nil
      assert is_float(rate)

      assert RenderHelpers.money_to_string(Money.new(payment_sub_amount, currency)) ==
               payment_display
    end

    test "invoice creation fail", %{conn: conn} do
      {_, _, response} =
        assert_error_sent(402, fn ->
          post(conn, "/api/v1/invoices", %{})
        end)

      assert %{
               "type" => "invalid_request_error",
               "message" => "Request Failed",
               "errors" => %{
                 "price" => "either `price` or `priceSubAmount` must be provided",
                 "priceSubAmount" => "either `price` or `priceSubAmount` must be provided",
                 "priceCurrency" => "can't be blank"
               }
             } = Jason.decode!(response)

      {_, _, response} =
        assert_error_sent(402, fn ->
          post(conn, "/api/v1/invoices", %{
            price: "fail"
          })
        end)

      assert %{
               "type" => "invalid_request_error",
               "message" => "Request Failed",
               "errors" => %{
                 "price" => "is invalid",
                 "priceCurrency" => "can't be blank"
               }
             } = Jason.decode!(response)
    end
  end

  describe "draft" do
    setup [:setup_draft]

    test "finalize", %{conn: conn, invoice: invoice} do
      conn = post(conn, "/api/v1/invoices/#{invoice.id}/finalize")

      id = invoice.id
      currency = Atom.to_string(invoice.payment_currency_id)

      assert %{
               "id" => ^id,
               "address" => address,
               "price" => 1.2,
               "priceSubAmount" => 120,
               "priceCurrency" => "USD",
               "paymentCurrency" => ^currency,
               "status" => "open"
             } = json_response(conn, 200)

      assert address != nil
    end

    test "get invoice", %{conn: conn, invoice_id: id, currency_id: currency_id} do
      conn = get(conn, "/api/v1/invoices/#{id}")
      currency = Atom.to_string(currency_id)
      assert %{"id" => ^id, "paymentCurrency" => ^currency} = json_response(conn, 200)
    end

    test "delete", %{conn: conn, invoice_id: id} do
      conn = delete(conn, "/api/v1/invoices/#{id}")
      assert %{"id" => ^id, "deleted" => true} = json_response(conn, 200)
    end

    test "cannot mark a draft as paid", %{conn: conn, invoice_id: id} do
      {_, _, response} =
        assert_error_sent(402, fn ->
          post(conn, "/api/v1/invoices/#{id}/pay")
        end)

      assert %{
               "type" => "invalid_request_error",
               "code" => "invalid_transition",
               "message" => "invalid transition from `draft` to `paid`"
             } = Jason.decode!(response)
    end

    test "cannot void a draft", %{conn: conn, invoice_id: id} do
      {_, _, response} =
        assert_error_sent(402, fn ->
          post(conn, "/api/v1/invoices/#{id}/void")
        end)

      assert %{
               "type" => "invalid_request_error",
               "code" => "invalid_transition",
               "message" => "invalid transition from `draft` to `void`"
             } = Jason.decode!(response)
    end

    test "update price", %{conn: conn, invoice: invoice} do
      conn =
        post(conn, "/api/v1/invoices/#{invoice.id}", %{
          price: 7.0,
          priceCurrency: "EUR"
        })

      assert %{
               "priceSubAmount" => 700,
               "priceCurrency" => "EUR",
               "priceDisplay" => "€7.00",
               "rates" => rates
             } = json_response(conn, 200)

      assert rates != nil
      assert InvoiceRates.find_base_with_rate(rates, "EUR") != :not_found
    end

    @tag payment_currency_id: nil
    test "set price to crypto if no payment_currency has been selected", %{
      conn: conn,
      invoice: invoice
    } do
      assert invoice.payment_currency_id == nil

      conn =
        post(conn, "/api/v1/invoices/#{invoice.id}", %{
          priceSubAmount: 1_000_000,
          priceCurrency: "DGC"
        })

      assert %{
               "priceSubAmount" => 1_000_000,
               "priceCurrency" => "DGC",
               "priceDisplay" => "0.01 DGC",
               "paymentCurrency" => "DGC",
               "paymentSubAmount" => 1_000_000,
               "paymentDisplay" => "0.01 DGC"
             } = json_response(conn, 200)
    end

    test "cannot set price to crypto if payment is in another crypto", %{
      conn: conn,
      invoice: invoice
    } do
      assert invoice.payment_currency_id != nil

      {_, _, response} =
        assert_error_sent(402, fn ->
          post(conn, "/api/v1/invoices/#{invoice.id}", %{
            priceSubAmount: 1_000_000,
            priceCurrency: "DGC"
          })
        end)

      price_error =
        "must be the same as payment currency `#{invoice.payment_currency_id}` when priced in crypto"

      assert %{
               "type" => "invalid_request_error",
               "message" => "Request Failed",
               "errors" => %{
                 "priceCurrency" => ^price_error
               }
             } = Jason.decode!(response)
    end

    test "if price is specified, need priceCurrency", %{conn: conn, invoice: invoice} do
      {_, _, response} =
        assert_error_sent(402, fn ->
          post(conn, "/api/v1/invoices/#{invoice.id}", %{
            price: 7.0
          })
        end)

      assert %{
               "type" => "invalid_request_error",
               "message" => "Request Failed",
               "errors" => %{
                 "priceCurrency" => "can't be empty if either `price` or `priceSubAmount` is set"
               }
             } = Jason.decode!(response)
    end

    test "if priceSubAmount is specified, need priceCurrency", %{conn: conn, invoice: invoice} do
      {_, _, response} =
        assert_error_sent(402, fn ->
          post(conn, "/api/v1/invoices/#{invoice.id}", %{
            priceSubAmount: 700
          })
        end)

      assert %{
               "type" => "invalid_request_error",
               "message" => "Request Failed",
               "errors" => %{
                 "priceCurrency" => "can't be empty if either `price` or `priceSubAmount` is set"
               }
             } = Jason.decode!(response)
    end

    test "if priceCurrency is specified, need price or priceSubAmount", %{
      conn: conn,
      invoice: invoice
    } do
      {_, _, response} =
        assert_error_sent(402, fn ->
          post(conn, "/api/v1/invoices/#{invoice.id}", %{
            priceCurrency: "EUR"
          })
        end)

      assert %{
               "type" => "invalid_request_error",
               "message" => "Request Failed",
               "errors" => %{
                 "price" => "either `price` or `priceSubAmount` must be provided",
                 "priceSubAmount" => "either `price` or `priceSubAmount` must be provided"
               }
             } = Jason.decode!(response)
    end

    test "change paymentCurrency", %{conn: conn, invoice: invoice} do
      currency_id = :DGC
      assert invoice.payment_currency_id != currency_id
      currency = Atom.to_string(currency_id)

      conn =
        post(conn, "/api/v1/invoices/#{invoice.id}", %{
          paymentCurrency: currency
        })

      assert %{
               "priceCurrency" => "USD",
               "paymentCurrency" => ^currency,
               "paymentSubAmount" => sub_amount,
               "paymentDisplay" => display,
               "rates" => %{^currency => %{"USD" => rate}}
             } = json_response(conn, 200)

      assert is_integer(sub_amount)
      assert display != nil
      assert is_float(rate)

      assert decimal_eq(
               ExchangeRates.calculate_rate(
                 Money.new(sub_amount, currency_id),
                 Money.parse!("1.2", "USD")
               ),
               Decimal.from_float(rate)
             )
    end

    test "validates priceCurrency", %{conn: conn, invoice_id: id} do
      {_, _, response} =
        assert_error_sent(402, fn ->
          post(conn, "/api/v1/invoices/#{id}", %{
            price: 1.0,
            priceCurrency: "XXX"
          })
        end)

      assert %{
               "type" => "invalid_request_error",
               "message" => "Request Failed",
               "errors" => %{
                 "priceCurrency" => "is invalid or not supported"
               }
             } = Jason.decode!(response)
    end

    test "validates paymentCurrency", %{conn: conn, invoice_id: id} do
      {_, _, response} =
        assert_error_sent(402, fn ->
          post(conn, "/api/v1/invoices/#{id}", %{
            paymentCurrency: "XXX"
          })
        end)

      assert %{
               "type" => "invalid_request_error",
               "message" => "Request Failed",
               "errors" => %{
                 "paymentCurrency" => "is invalid or not supported"
               }
             } = Jason.decode!(response)
    end

    test "update meta fields", %{conn: conn, invoice_id: id} do
      conn =
        post(conn, "/api/v1/invoices/#{id}", %{
          description: "My awesome invoice",
          email: "test@bitpal.dev",
          orderId: "id:123",
          posData: %{
            "some" => "data",
            "other" => %{"even_more" => 0.1337}
          }
        })

      assert %{
               "description" => "My awesome invoice",
               "email" => "test@bitpal.dev",
               "orderId" => "id:123",
               "posData" => %{
                 "some" => "data",
                 "other" => %{"even_more" => 0.1337}
               }
             } = json_response(conn, 200)
    end
  end

  describe "open invoice" do
    setup [:setup_open]

    test "cannot delete a finalized invoice", %{conn: conn, invoice_id: id} do
      {_, _, response} =
        assert_error_sent(402, fn ->
          delete(conn, "/api/v1/invoices/#{id}")
        end)

      assert %{
               "type" => "invalid_request_error",
               "code" => "invoice_not_editable"
             } = Jason.decode!(response)
    end

    test "get a partially paid invoice", %{conn: conn, invoice_id: id} do
      invoice = Invoices.fetch!(id)

      paid = Money.parse!(0.3, invoice.payment_currency_id)
      BackendMock.tx_seen(%{invoice | expected_payment: paid})

      paid_amount = paid.amount

      conn = get(conn, "/api/v1/invoices/#{id}")

      assert %{
               "paidDisplay" => "0.3 " <> _,
               "paidSubAmount" => ^paid_amount
             } = json_response(conn, 200)
    end
  end

  describe "uncollectable" do
    setup [:setup_uncollectable]

    test "pay an uncollectable invoice", %{conn: conn, invoice_id: id} do
      conn = post(conn, "/api/v1/invoices/#{id}/pay")
      assert %{"id" => ^id, "status" => "paid"} = json_response(conn, 200)
    end

    test "void an uncollectable invoice", %{conn: conn, invoice_id: id} do
      conn = post(conn, "/api/v1/invoices/#{id}/void")
      assert %{"id" => ^id, "status" => "void"} = json_response(conn, 200)
    end
  end

  test "not found", %{conn: conn} do
    id = "not-found"

    for f <- [
          fn -> get(conn, "/api/v1/invoices/#{id}") end,
          fn -> post(conn, "/api/v1/invoices/#{id}", %{"amount" => "2.0"}) end,
          fn -> delete(conn, "/api/v1/invoices/#{id}") end,
          fn -> post(conn, "/api/v1/invoices/#{id}/finalize") end,
          fn -> post(conn, "/api/v1/invoices/#{id}/pay") end,
          fn -> post(conn, "/api/v1/invoices/#{id}/void") end
        ] do
      {_, _, response} = assert_error_sent(404, f)

      assert %{
               "type" => "invalid_request_error",
               "code" => "resource_missing",
               "param" => "id",
               "message" => _
             } = Jason.decode!(response)
    end
  end

  test "other invoices not found", %{conn: conn} do
    id = create_invoice().id

    for f <- [
          fn -> get(conn, "/api/v1/invoices/#{id}") end,
          fn -> post(conn, "/api/v1/invoices/#{id}", %{"amount" => "2.0"}) end,
          fn -> delete(conn, "/api/v1/invoices/#{id}") end,
          fn -> post(conn, "/api/v1/invoices/#{id}/finalize") end,
          fn -> post(conn, "/api/v1/invoices/#{id}/pay") end,
          fn -> post(conn, "/api/v1/invoices/#{id}/void") end
        ] do
      {_, _, response} = assert_error_sent(404, f)

      assert %{
               "type" => "invalid_request_error",
               "code" => "resource_missing",
               "param" => "id",
               "message" => _
             } = Jason.decode!(response)
    end
  end

  @tag auth: false
  test "unauthorized", %{conn: conn} do
    id = create_invoice().id

    for f <- [
          fn -> post(conn, "/api/v1/invoices/", %{"amount" => "1.0", "currency" => "BCH"}) end,
          fn -> get(conn, "/api/v1/invoices/#{id}") end,
          fn -> post(conn, "/api/v1/invoices/#{id}", %{"amount" => "2.0"}) end,
          fn -> delete(conn, "/api/v1/invoices/#{id}") end,
          fn -> post(conn, "/api/v1/invoices/#{id}/finalize") end,
          fn -> post(conn, "/api/v1/invoices/#{id}/pay") end,
          fn -> post(conn, "/api/v1/invoices/#{id}/void") end,
          fn -> get(conn, "/api/v1/invoices") end
        ] do
      {_, _, response} = assert_error_sent(401, f)

      assert %{
               "type" => "api_connection_error",
               "message" => _
             } = Jason.decode!(response)
    end
  end

  test "show all invoices", %{conn: conn} do
    id0 = create_invoice(conn, amount: 1).id
    id1 = create_invoice(conn, amount: 2).id
    id2 = create_invoice(conn, amount: 3, status: :open).id

    # Invoices from other store should not show up
    _ = create_invoice(amount: 4)

    conn = get(conn, "/api/v1/invoices")
    # Can sometimes be in another order, so sorting is necessary
    [id0, id1, id2] = Enum.sort([id0, id1, id2])

    assert [%{"id" => ^id0}, %{"id" => ^id1}, %{"id" => ^id2}] =
             Enum.sort_by(json_response(conn, 200), fn %{"id" => id} -> id end, &</2)
  end

  defp setup_draft(context) do
    setup_invoice(context, price: Money.parse!(1.2, :USD), status: :draft)
  end

  defp setup_open(context) do
    setup_invoice(context,
      price: Money.parse!(1.2, :USD),
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
      Map.take(context, [:payment_currency_id])
      |> Map.merge(Map.new(attrs))

    add_invoice(context, invoice_attrs)
  end
end
