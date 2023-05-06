defmodule BitPalApi.ExchangeRateControllerTest do
  use BitPalApi.ConnCase, async: true, integration: false
  alias BitPal.ExchangeRates

  setup do
    c1 = unique_currency_id()
    c2 = unique_currency_id()

    f1 = unique_fiat()
    f2 = unique_fiat()

    ExchangeRates.update_exchange_rate(rate_params(pair: {c1, f1}, rate: Decimal.from_float(1.1)))
    ExchangeRates.update_exchange_rate(rate_params(pair: {c1, f2}, rate: Decimal.from_float(2.1)))
    ExchangeRates.update_exchange_rate(rate_params(pair: {c2, f1}, rate: Decimal.from_float(3.1)))

    %{
      c1: Atom.to_string(c1),
      c2: Atom.to_string(c2),
      c3: Atom.to_string(unique_currency_id()),
      f1: Atom.to_string(f1),
      f2: Atom.to_string(f2)
    }
  end

  describe "/rates" do
    test "/rates", %{conn: conn, c1: c1, c2: c2, f1: f1, f2: f2} do
      conn = get(conn, "/api/v1/rates")

      assert %{
               ^c1 => %{
                 ^f1 => 1.1,
                 ^f2 => 2.1
               },
               ^c2 => %{
                 ^f1 => 3.1
               }
             } = json_response(conn, 200)
    end
  end

  describe "/rates/:base" do
    test "get", %{conn: conn, c1: c1, f1: f1, f2: f2} do
      conn = get(conn, "/api/v1/rates/#{c1}")

      assert %{
               c1 => %{
                 f1 => 1.1,
                 f2 => 2.1
               }
             } == json_response(conn, 200)
    end

    test "not found", %{conn: conn, c3: c3} do
      {_, _, response} =
        assert_error_sent(404, fn ->
          get(conn, "/api/v1/rates/#{c3}")
        end)

      msg = "Exchange rate for `#{c3}` not found"

      assert %{
               "message" => ^msg,
               "param" => "base",
               "type" => "invalid_request_error",
               "code" => "resource_missing"
             } = Jason.decode!(response)
    end

    test "bad base", %{conn: conn} do
      {_, _, response} =
        assert_error_sent(402, fn ->
          get(conn, "/api/v1/rates/XXX")
        end)

      assert %{
               "message" => "is invalid or not supported",
               "param" => "base",
               "type" => "invalid_request_error",
               "code" => "invalid_currency"
             } = Jason.decode!(response)
    end
  end

  describe "/rates/:basecurrency/:currency" do
    test "get", %{conn: conn, c1: c1, f2: f2} do
      conn = get(conn, "/api/v1/rates/#{c1}/#{f2}")

      assert %{c1 => %{f2 => 2.1}} == json_response(conn, 200)
    end

    test "not found", %{conn: conn, c2: c2, f2: f2} do
      {_, _, response} =
        assert_error_sent(404, fn ->
          get(conn, "/api/v1/rates/#{c2}/#{f2}")
        end)

      msg = "Exchange rate for pair `#{c2}-#{f2}` not found"

      assert %{
               "message" => ^msg,
               "param" => "pair",
               "type" => "invalid_request_error",
               "code" => "resource_missing"
             } = Jason.decode!(response)
    end

    test "bad base", %{conn: conn, f2: f2} do
      {_, _, response} =
        assert_error_sent(402, fn ->
          get(conn, "/api/v1/rates/XXX/#{f2}")
        end)

      assert %{
               "message" => "is invalid or not supported",
               "param" => "base",
               "type" => "invalid_request_error",
               "code" => "invalid_currency"
             } = Jason.decode!(response)
    end

    test "not a crypto base", %{conn: conn, f1: f1, f2: f2} do
      {_, _, response} =
        assert_error_sent(402, fn ->
          get(conn, "/api/v1/rates/#{f2}/#{f1}")
        end)

      assert %{
               "message" => "not a supported cryptocurrency",
               "param" => "base",
               "type" => "invalid_request_error",
               "code" => "invalid_currency"
             } = Jason.decode!(response)
    end

    test "bad quote", %{conn: conn, c1: c1} do
      {_, _, response} =
        assert_error_sent(402, fn ->
          get(conn, "/api/v1/rates/#{c1}/XXX")
        end)

      assert %{
               "message" => "is invalid or not supported",
               "param" => "quote",
               "type" => "invalid_request_error",
               "code" => "invalid_currency"
             } = Jason.decode!(response)
    end
  end
end
