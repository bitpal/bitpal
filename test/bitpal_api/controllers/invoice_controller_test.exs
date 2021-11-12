defmodule BitPalApi.InvoiceControllerTest do
  use BitPalApi.ConnCase, async: true

  describe "create" do
    test "basic", %{conn: conn, currency_id: currency_id} do
      # FIXME should use this
      # attrs = valid_invoice_attributes(currency_id: currency_id)
      # conn = post(conn, "/v1/invoices", attrs)

      conn =
        post(conn, "/v1/invoices", %{
          amount: "1.2",
          exchange_rate: "2.0",
          currency_id: currency_id,
          fiat_currency: "USD",
          email: "test@bitpal.dev",
          description: "My awesome invoice",
          pos_data: %{
            "some" => "data",
            "other" => %{"even_more" => 0}
          }
        })

      currency = Atom.to_string(currency_id)

      assert %{
               "id" => id,
               "address" => nil,
               "amount" => "1.20" <> _,
               "currency" => ^currency,
               "fiat_amount" => "2.40",
               "fiat_currency" => "USD",
               "required_confirmations" => 0,
               "status" => "draft",
               "email" => "test@bitpal.dev",
               "description" => "My awesome invoice",
               "pos_data" => %{
                 "some" => "data",
                 "other" => %{"even_more" => 0}
               }
             } = json_response(conn, 200)

      assert id != nil
    end

    test "create and finalize", %{conn: conn, currency_id: currency_id} do
      conn =
        post(conn, "/v1/invoices", %{
          "amount" => "1.2",
          "exchange_rate" => "2.0",
          "currency_id" => currency_id,
          "fiat_currency" => "USD",
          "finalize" => true
        })

      currency = Atom.to_string(currency_id)

      assert %{
               "id" => id,
               "address" => address,
               "amount" => "1.20" <> _,
               "currency" => ^currency,
               "fiat_amount" => "2.40",
               "fiat_currency" => "USD",
               "required_confirmations" => 0,
               "status" => "open"
             } = json_response(conn, 200)

      assert id != nil
      assert address != nil
    end

    test "invoice creation fail", %{conn: conn} do
      {_, _, response} =
        assert_error_sent(402, fn ->
          post(conn, "/v1/invoices", %{
            amount: "fail"
          })
        end)

      assert %{
               "type" => "invalid_request_error",
               "message" => "Request Failed",
               "errors" => %{
                 "fiat_amount" => "must provide amount in either crypto or fiat",
                 "amount" => "must provide amount in either crypto or fiat",
                 "currency_id" => "cannot be empty"
               }
             } = Jason.decode!(response)
    end
  end

  describe "draft" do
    setup [:setup_draft]

    test "finalize", %{conn: conn, invoice: invoice} do
      conn = post(conn, "/v1/invoices/#{invoice.id}/finalize")

      id = invoice.id
      currency = Atom.to_string(invoice.currency_id)
      fiat_currency = Atom.to_string(invoice.fiat_amount.currency)

      assert %{
               "id" => ^id,
               "address" => address,
               "amount" => "1.20" <> _,
               "currency" => ^currency,
               "fiat_amount" => "2.40",
               "fiat_currency" => ^fiat_currency,
               "status" => "open"
             } = json_response(conn, 200)

      assert address != nil
    end

    test "get invoice", %{conn: conn, invoice_id: id, currency_id: currency_id} do
      conn = get(conn, "/v1/invoices/#{id}")
      currency = Atom.to_string(currency_id)
      assert %{"id" => ^id, "currency" => ^currency} = json_response(conn, 200)
    end

    test "delete", %{conn: conn, invoice_id: id} do
      conn = delete(conn, "/v1/invoices/#{id}")
      assert %{"id" => ^id, "deleted" => true} = json_response(conn, 200)
    end

    test "cannot mark a draft as paid", %{conn: conn, invoice_id: id} do
      {_, _, response} =
        assert_error_sent(402, fn ->
          post(conn, "/v1/invoices/#{id}/pay")
        end)

      assert %{
               "type" => "invalid_request_error",
               "code" => "invalid_transition",
               "message" => "invalid transition from 'draft' to 'paid'"
             } = Jason.decode!(response)
    end

    test "cannot void a draft", %{conn: conn, invoice_id: id} do
      {_, _, response} =
        assert_error_sent(402, fn ->
          post(conn, "/v1/invoices/#{id}/void")
        end)

      assert %{
               "type" => "invalid_request_error",
               "code" => "invalid_transition",
               "message" => "invalid transition from 'draft' to 'void'"
             } = Jason.decode!(response)
    end

    test "update amount", %{conn: conn, invoice: invoice} do
      conn =
        post(conn, "/v1/invoices/#{invoice.id}", %{
          amount: "7.0"
        })

      currency = Atom.to_string(invoice.currency_id)
      fiat_currency = Atom.to_string(invoice.fiat_amount.currency)

      assert %{
               "amount" => "7.0" <> _,
               "currency" => ^currency,
               "fiat_amount" => "14.00",
               "fiat_currency" => ^fiat_currency
             } = json_response(conn, 200)
    end

    test "update fiat amount", %{conn: conn, invoice: invoice} do
      conn =
        post(conn, "/v1/invoices/#{invoice.id}", %{
          fiat_amount: "8"
        })

      currency = Atom.to_string(invoice.currency_id)
      fiat_currency = Atom.to_string(invoice.fiat_amount.currency)

      assert %{
               "amount" => "4.0" <> _,
               "currency" => ^currency,
               "fiat_amount" => "8.00",
               "fiat_currency" => ^fiat_currency
             } = json_response(conn, 200)
    end

    test "update exchange rate", %{conn: conn, invoice: invoice} do
      conn =
        post(conn, "/v1/invoices/#{invoice.id}", %{
          exchange_rate: "3.0"
        })

      currency = Atom.to_string(invoice.currency_id)
      fiat_currency = Atom.to_string(invoice.fiat_amount.currency)

      assert %{
               "amount" => "1.20" <> _,
               "currency" => ^currency,
               "fiat_amount" => "3.60",
               "fiat_currency" => ^fiat_currency
             } = json_response(conn, 200)
    end

    test "update amount and exchange rate", %{conn: conn, invoice: invoice} do
      conn =
        post(conn, "/v1/invoices/#{invoice.id}", %{
          amount: "7.0",
          exchange_rate: "3.0"
        })

      currency = Atom.to_string(invoice.currency_id)
      fiat_currency = Atom.to_string(invoice.fiat_amount.currency)

      assert %{
               "amount" => "7.0" <> _,
               "currency" => ^currency,
               "fiat_amount" => "21.00",
               "fiat_currency" => ^fiat_currency
             } = json_response(conn, 200)
    end

    test "change currency", %{conn: conn, invoice_id: id, currency_id: currency_id} do
      currency = Atom.to_string(currency_id)

      conn =
        post(conn, "/v1/invoices/#{id}", %{
          amount: "7.0",
          currency: currency
        })

      assert %{
               "amount" => "7.0" <> _,
               "currency" => ^currency
             } = json_response(conn, 200)
    end

    test "cannot change just fiat currency", %{conn: conn, invoice_id: id} do
      {_, _, response} =
        assert_error_sent(402, fn ->
          post(conn, "/v1/invoices/#{id}", %{
            amount: "fail"
          })
        end)

      assert %{
               "type" => "invalid_request_error",
               "message" => "Request Failed",
               "errors" => %{
                 "amount" => "is invalid"
               }
             } = Jason.decode!(response)
    end

    test "update many", %{conn: conn, invoice_id: id, currency_id: currency_id} do
      currency = Atom.to_string(currency_id)

      conn =
        post(conn, "/v1/invoices/#{id}", %{
          amount: "7.0",
          currency: currency,
          exchange_rate: "3.0",
          fiat_currency: "USD",
          email: "test@bitpal.dev",
          description: "My awesome invoice",
          pos_data: %{
            "some" => "data",
            "other" => %{"even_more" => 0}
          }
        })

      assert %{
               "amount" => "7.0" <> _,
               "currency" => ^currency,
               "fiat_amount" => "21.00",
               "fiat_currency" => "USD",
               "email" => "test@bitpal.dev",
               "description" => "My awesome invoice",
               "pos_data" => %{
                 "some" => "data",
                 "other" => %{"even_more" => 0}
               }
             } = json_response(conn, 200)
    end
  end

  describe "open invoice" do
    setup [:setup_open]

    test "cannot delete a finalized invoice", %{conn: conn, invoice_id: id} do
      {_, _, response} =
        assert_error_sent(402, fn ->
          delete(conn, "/v1/invoices/#{id}")
        end)

      assert %{
               "type" => "invalid_request_error",
               "code" => "invoice_not_editable"
             } = Jason.decode!(response)
    end
  end

  describe "uncollectable" do
    setup [:setup_uncollectable]

    test "pay an uncollectable invoice", %{conn: conn, invoice_id: id} do
      conn = post(conn, "/v1/invoices/#{id}/pay")
      assert %{"id" => ^id, "status" => "paid"} = json_response(conn, 200)
    end

    test "void an uncollectable invoice", %{conn: conn, invoice_id: id} do
      conn = post(conn, "/v1/invoices/#{id}/void")
      assert %{"id" => ^id, "status" => "void"} = json_response(conn, 200)
    end
  end

  test "not found", %{conn: conn} do
    id = "not-found"

    for f <- [
          fn -> get(conn, "/v1/invoices/#{id}") end,
          fn -> post(conn, "/v1/invoices/#{id}", %{"amount" => "2.0"}) end,
          fn -> delete(conn, "/v1/invoices/#{id}") end,
          fn -> post(conn, "/v1/invoices/#{id}/finalize") end,
          fn -> post(conn, "/v1/invoices/#{id}/pay") end,
          fn -> post(conn, "/v1/invoices/#{id}/void") end
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
          fn -> get(conn, "/v1/invoices/#{id}") end,
          fn -> post(conn, "/v1/invoices/#{id}", %{"amount" => "2.0"}) end,
          fn -> delete(conn, "/v1/invoices/#{id}") end,
          fn -> post(conn, "/v1/invoices/#{id}/finalize") end,
          fn -> post(conn, "/v1/invoices/#{id}/pay") end,
          fn -> post(conn, "/v1/invoices/#{id}/void") end
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
          fn -> post(conn, "/v1/invoices/", %{"amount" => "1.0", "currency" => "BCH"}) end,
          fn -> get(conn, "/v1/invoices/#{id}") end,
          fn -> post(conn, "/v1/invoices/#{id}", %{"amount" => "2.0"}) end,
          fn -> delete(conn, "/v1/invoices/#{id}") end,
          fn -> post(conn, "/v1/invoices/#{id}/finalize") end,
          fn -> post(conn, "/v1/invoices/#{id}/pay") end,
          fn -> post(conn, "/v1/invoices/#{id}/void") end,
          fn -> get(conn, "/v1/invoices") end
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

    conn = get(conn, "/v1/invoices")
    # Can sometimes be in another order, so sorting is necessary
    [id0, id1, id2] = Enum.sort([id0, id1, id2])

    assert [%{"id" => ^id0}, %{"id" => ^id1}, %{"id" => ^id2}] =
             Enum.sort_by(json_response(conn, 200), fn %{"id" => id} -> id end, &</2)
  end

  defp setup_draft(context) do
    add_invoice(context, amount: "1.2", exchange_rate: "2.0", status: :draft)
  end

  defp setup_open(context) do
    add_invoice(context,
      address_id: :auto,
      status: :open
    )
  end

  defp setup_uncollectable(context) do
    add_invoice(context,
      address_id: :auto,
      status: :uncollectible
    )
  end
end
