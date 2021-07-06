defmodule BitPalApi.InvoiceControllerTest do
  use BitPalApi.ConnCase
  alias BitPal.Invoices

  test "create invoice", %{conn: conn} do
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

  @tag backends: true
  test "create then finalize", %{conn: conn} do
    conn =
      post(conn, "/v1/invoices", %{
        "amount" => "1.2",
        "exchange_rate" => "2.0",
        "currency" => "BCH",
        "fiat_currency" => "USD"
      })

    assert %{
             "id" => id,
             "address" => nil,
             "amount" => "1.2",
             "currency" => "BCH",
             "fiat_amount" => "2.4",
             "fiat_currency" => "USD",
             "status" => "draft"
           } = json_response(conn, 200)

    assert id != nil

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

  test "invoice creation fail", %{conn: conn} do
    {_, _, response} =
      assert_error_sent(400, fn ->
        post(conn, "/v1/invoices", %{
          amount: "fail"
        })
      end)

    assert %{"errors" => _} = Jason.decode!(response)
  end

  test "get invoice", %{conn: conn} do
    %{id: id} = invoice()

    conn = get(conn, "/v1/invoices/#{id}")
    assert %{"id" => ^id, "currency" => "BCH"} = json_response(conn, 200)
  end

  test "invoice not found", %{conn: conn} do
    assert_error_sent(404, fn ->
      get(conn, "/v1/invoices/not-found")
    end)
  end

  defp invoice(params \\ %{}) do
    {:ok, invoice} =
      Map.merge(
        %{
          amount: 1.2,
          exchange_rate: 2.0,
          currency: "BCH",
          fiat_currency: "USD"
        },
        params
      )
      |> Invoices.register()

    invoice
  end
end
