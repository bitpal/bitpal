defmodule BitPalApi.AuthTest do
  use BitPalApi.ConnCase, async: true

  defp protected_requests do
    [
      {:post, "/v1/invoices"},
      {:get, "/v1/invoices/0"},
      {:post, "/v1/invoices/0"},
      {:delete, "/v1/invoices/0"},
      {:post, "/v1/invoices/0/finalize"},
      {:post, "/v1/invoices/0/pay"},
      {:post, "/v1/invoices/0/void"},
      {:get, "/v1/invoices"},
      {:get, "/v1/transactions/0"},
      {:get, "/v1/transactions"},
      {:get, "/v1/rates/BCH"},
      {:get, "/v1/rates/BCH/USD"},
      {:get, "/v1/currencies"},
      {:get, "/v1/currencies/BCH"}
    ]
  end

  defp assert_protected_requests(conn) do
    for {request, path} <- protected_requests() do
      assert_error_sent(401, fn ->
        case request do
          :get -> get(conn, path)
          :post -> post(conn, path)
          :delete -> delete(conn, path)
        end
      end)
    end
  end

  @tag auth: false
  test "failed auths", %{conn: conn} do
    assert_protected_requests(conn)
  end

  @tag token: "bad token"
  test "bad token auth", %{conn: conn} do
    assert_protected_requests(conn)
  end
end
