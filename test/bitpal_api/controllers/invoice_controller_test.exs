defmodule BitPalApi.InvoiceControllerTest do
  use BitPalApi.ConnCase
  alias BitPal.ExchangeRate
  alias BitPal.Invoices

  test "create invoice", %{conn: conn} do
    conn =
      post(conn, "/v1/invoices", %{
        amount: Money.parse!(1.2, :BCH),
        exchange_rate: ExchangeRate.new!(Decimal.from_float(2.0), {:BCH, :USD})
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
      params
      |> Map.put_new(:amount, Money.parse!(1.2, :BCH))
      |> Map.put_new(:exchange_rate, ExchangeRate.new!(Decimal.from_float(2.0), {:BCH, :USD}))
      |> Invoices.register()

    invoice
  end
end
