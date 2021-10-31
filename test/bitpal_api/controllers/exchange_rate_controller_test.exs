defmodule BitPalApi.ExchangeRateControllerTest do
  use BitPalApi.ConnCase, async: true

  # NOTE that this sometimes fails with errors
  test "show a rate", %{conn: conn} do
    conn = get(conn, "/v1/rates/BCH/USD")

    assert %{
             "rate" => "815.27",
             "code" => "USD",
             "name" => "US Dollar"
           } = json_response(conn, 200)
  end

  test "show all rates for a currency", %{conn: conn} do
    conn = get(conn, "/v1/rates/BCH")

    assert [
             %{
               "rate" => "815.27",
               "code" => "USD",
               "name" => "US Dollar"
             },
             %{
               "rate" => "741.62",
               "code" => "EUR",
               "name" => "Euro"
             }
           ] = json_response(conn, 200)
  end
end
