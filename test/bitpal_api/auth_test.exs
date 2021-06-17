defmodule BitPalApi.AuthTest do
  use BitPalApi.ConnCase

  defp protected_requests do
    [
      {:post, "/v1/invoices"},
      {:get, "/v1/invoices/0"}
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

  @tag user: "bad_user"
  test "bad user auth", %{conn: conn} do
    assert_protected_requests(conn)
  end

  @tag pass: "bad_pass"
  test "bad pass auth", %{conn: conn} do
    assert_protected_requests(conn)
  end
end
