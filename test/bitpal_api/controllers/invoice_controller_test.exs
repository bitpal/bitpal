defmodule BitPalApi.InvoiceControllerTest do
  use BitPalApi.ConnCase
  alias BitPal.Invoices
  alias BitPalApi.Authentication.BasicAuth

  describe "create" do
    test "basic", %{conn: conn} do
      conn =
        post(conn, "/v1/invoices", %{
          amount: "1.2",
          exchange_rate: "2.0",
          currency: "BCH",
          fiat_currency: "USD"
        })

      assert %{
               "id" => id,
               "address" => nil,
               "amount" => "1.2",
               "currency" => "BCH",
               "fiat_amount" => "2.4",
               "fiat_currency" => "USD",
               "required_confirmations" => 0,
               "status" => "draft"
             } = json_response(conn, 200)

      assert id != nil
    end

    @tag backends: true
    test "create and finalize", %{conn: conn} do
      conn =
        post(conn, "/v1/invoices", %{
          "amount" => "1.2",
          "exchange_rate" => "2.0",
          "currency" => "BCH",
          "fiat_currency" => "USD",
          "finalize" => true
        })

      assert %{
               "id" => id,
               "address" => address,
               "amount" => "1.2",
               "currency" => "BCH",
               "fiat_amount" => "2.4",
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
                 "currency" => "cannot be empty"
               }
             } = Jason.decode!(response)
    end
  end

  describe "draft" do
    setup [:setup_draft]

    @tag backends: true
    test "finalize", %{conn: conn, id: id} do
      conn = post(conn, "/v1/invoices/#{id}/finalize")

      assert %{
               "id" => ^id,
               "address" => address,
               "amount" => "1.2",
               "currency" => "BCH",
               "fiat_amount" => "2.4",
               "fiat_currency" => "USD",
               "status" => "open"
             } = json_response(conn, 200)

      assert address != nil
    end

    test "get invoice", %{conn: conn, id: id} do
      conn = get(conn, "/v1/invoices/#{id}")
      assert %{"id" => ^id, "currency" => "BCH"} = json_response(conn, 200)
    end

    test "delete", %{conn: conn, id: id} do
      conn = delete(conn, "/v1/invoices/#{id}")
      assert %{"id" => ^id, "deleted" => true} = json_response(conn, 200)
    end

    test "cannot mark a draft as paid", %{conn: conn, id: id} do
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

    test "cannot void a draft", %{conn: conn, id: id} do
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

    test "update amount", %{conn: conn, id: id} do
      conn =
        post(conn, "/v1/invoices/#{id}", %{
          amount: "7.0"
        })

      assert %{
               "amount" => "7.0",
               "currency" => "BCH",
               "fiat_amount" => "14.0",
               "fiat_currency" => "USD"
             } = json_response(conn, 200)
    end

    test "update fiat amount", %{conn: conn, id: id} do
      conn =
        post(conn, "/v1/invoices/#{id}", %{
          fiat_amount: "8"
        })

      assert %{
               "amount" => "4.0",
               "currency" => "BCH",
               "fiat_amount" => "8.0",
               "fiat_currency" => "USD"
             } = json_response(conn, 200)
    end

    test "update exchange rate", %{conn: conn, id: id} do
      conn =
        post(conn, "/v1/invoices/#{id}", %{
          exchange_rate: "3.0"
        })

      assert %{
               "amount" => "1.2",
               "currency" => "BCH",
               "fiat_amount" => "3.6",
               "fiat_currency" => "USD"
             } = json_response(conn, 200)
    end

    test "update amount and exchange rate", %{conn: conn, id: id} do
      conn =
        post(conn, "/v1/invoices/#{id}", %{
          amount: "7.0",
          exchange_rate: "3.0"
        })

      assert %{
               "amount" => "7.0",
               "currency" => "BCH",
               "fiat_amount" => "21.0",
               "fiat_currency" => "USD"
             } = json_response(conn, 200)
    end

    test "change currency", %{conn: conn, id: id} do
      conn =
        post(conn, "/v1/invoices/#{id}", %{
          amount: "7.0",
          currency: "XMR"
        })

      assert %{
               "amount" => "7.0",
               "currency" => "XMR"
             } = json_response(conn, 200)
    end

    test "cannot change just fiat currency", %{conn: conn, id: id} do
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

    test "update many", %{conn: conn, id: id} do
      conn =
        post(conn, "/v1/invoices/#{id}", %{
          amount: "7.0",
          currency: "XMR",
          exchange_rate: "3.0",
          fiat_currency: "USD"
        })

      assert %{
               "amount" => "7.0",
               "currency" => "XMR",
               "fiat_amount" => "21.0",
               "fiat_currency" => "USD"
             } = json_response(conn, 200)
    end
  end

  describe "open invoice" do
    setup [:setup_open]

    test "cannot delete a finalized invoice", %{conn: conn, id: id} do
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

    test "pay an uncollectable invoice", %{conn: conn, id: id} do
      conn = post(conn, "/v1/invoices/#{id}/pay")
      assert %{"id" => ^id, "status" => "paid"} = json_response(conn, 200)
    end

    test "void an uncollectable invoice", %{conn: conn, id: id} do
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
    store = create_store()
    id = draft(store.id).id

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
    store = create_store()
    id = draft(store.id).id

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
    {:ok, store_id} = BasicAuth.parse(conn)

    id0 = draft(store_id, %{amount: 1}).id
    id1 = draft(store_id, %{amount: 2}).id
    id2 = open_invoice(store_id, %{amount: 3}).id

    # Invoices from other store should not show up
    other_store = create_store()
    _other_id = draft(other_store.id, %{amount: 4}).id

    conn = get(conn, "/v1/invoices")
    # Can sometimes be in another order, so sorting is necessary
    [id0, id1, id2] = Enum.sort([id0, id1, id2])

    assert [%{"id" => ^id0}, %{"id" => ^id1}, %{"id" => ^id2}] =
             Enum.sort_by(json_response(conn, 200), fn %{"id" => id} -> id end, &</2)
  end

  # TODO
  # update

  # FIXME move to test helpers
  defp setup_draft(context) do
    {:ok, store_id} = BasicAuth.parse(context.conn)
    invoice = draft(store_id)

    context
    |> Map.put(:id, invoice.id)
    |> Map.put(:store_id, store_id)
  end

  defp setup_open(context) do
    {:ok, store_id} = BasicAuth.parse(context.conn)
    invoice = open_invoice(store_id)

    context
    |> Map.put(:id, invoice.id)
    |> Map.put(:store_id, store_id)
  end

  defp setup_uncollectable(context) do
    {:ok, store_id} = BasicAuth.parse(context.conn)
    invoice = canceled_invoice(store_id)

    context
    |> Map.put(:id, invoice.id)
    |> Map.put(:store_id, store_id)
  end

  defp draft(store_id, params \\ %{}) do
    params =
      Map.merge(
        %{
          amount: 1.2,
          exchange_rate: 2.0,
          currency: "BCH",
          fiat_currency: "USD"
        },
        params
      )

    {:ok, invoice} = Invoices.register(store_id, params)

    invoice
  end

  defp open_invoice(store_id, params \\ %{}) do
    Invoices.finalize!(%{draft(store_id, params) | address_id: generate_address_id()})
  end

  defp canceled_invoice(store_id, params \\ %{}) do
    open_invoice(store_id, params)
    |> Invoices.cancel!()
  end
end
