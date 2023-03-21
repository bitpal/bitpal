defmodule BitPalApi.ExchangeRateControllerTest do
  use BitPalApi.ConnCase, async: false
  alias BitPal.ExchangeRateCache
  alias BitPal.ExchangeRateSupervisor

  setup _tags do
    name = ExchangeRateSupervisor.cache_name()
    ExchangeRateCache.delete_all(name)

    ExchangeRateCache.update_exchange_rate(
      name,
      cache_rate(pair: {:BCH, :USD}, rate: Decimal.new("1.1"))
    )

    ExchangeRateCache.update_exchange_rate(
      name,
      cache_rate(pair: {:BCH, :EUR}, rate: Decimal.new("2.1"))
    )

    ExchangeRateCache.update_exchange_rate(
      name,
      cache_rate(pair: {:XMR, :USD}, rate: Decimal.new("3.1"))
    )
  end

  describe "/rates" do
    @tag do: true
    test "/rates", %{conn: conn} do
      conn = get(conn, "/v1/rates")

      assert %{
               "BCH" => %{
                 "USD" => 1.1,
                 "EUR" => 2.1
               },
               "XMR" => %{
                 "USD" => 3.1
               }
             } == json_response(conn, 200)
    end
  end

  describe "/rates/:base" do
    test "get", %{conn: conn} do
      conn = get(conn, "/v1/rates/BCH")

      assert %{
               "BCH" => %{
                 "USD" => 1.1,
                 "EUR" => 2.1
               }
             } == json_response(conn, 200)
    end

    test "not found", %{conn: conn} do
      {_, _, response} =
        assert_error_sent(404, fn ->
          get(conn, "/v1/rates/BTC")
        end)

      assert %{
               "message" => "Exchange rate for `BTC` not found",
               "param" => "base",
               "type" => "invalid_request_error",
               "code" => "resource_missing"
             } = Jason.decode!(response)
    end

    test "bad base", %{conn: conn} do
      {_, _, response} =
        assert_error_sent(402, fn ->
          get(conn, "/v1/rates/XXX")
        end)

      assert %{
               "message" => "Currency `XXX` is invalid or not supported",
               "param" => "base",
               "type" => "invalid_request_error",
               "code" => "invalid_currency"
             } = Jason.decode!(response)
    end
  end

  describe "/rates/:basecurrency/:currency" do
    test "get", %{conn: conn} do
      conn = get(conn, "/v1/rates/BCH/EUR")

      assert %{"BCH" => %{"EUR" => 2.1}} == json_response(conn, 200)
    end

    test "not found", %{conn: conn} do
      {_, _, response} =
        assert_error_sent(404, fn ->
          get(conn, "/v1/rates/BTC/SEK")
        end)

      assert %{
               "message" => "Exchange rate for pair `BTC-SEK` not found",
               "param" => "pair",
               "type" => "invalid_request_error",
               "code" => "resource_missing"
             } = Jason.decode!(response)
    end

    test "bad base", %{conn: conn} do
      {_, _, response} =
        assert_error_sent(402, fn ->
          get(conn, "/v1/rates/XXX/EUR")
        end)

      assert %{
               "message" => "Currency `XXX` is invalid or not supported",
               "param" => "base",
               "type" => "invalid_request_error",
               "code" => "invalid_currency"
             } = Jason.decode!(response)
    end

    test "bad quote", %{conn: conn} do
      {_, _, response} =
        assert_error_sent(402, fn ->
          get(conn, "/v1/rates/EUR/XXX")
        end)

      assert %{
               "message" => "Currency `XXX` is invalid or not supported",
               "param" => "quote",
               "type" => "invalid_request_error",
               "code" => "invalid_currency"
             } = Jason.decode!(response)
    end
  end
end
