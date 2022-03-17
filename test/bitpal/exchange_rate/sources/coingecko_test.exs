defmodule BitPal.ExchangeRate.CoingeckoTest do
  use ExUnit.Case, async: true
  import Mox
  alias BitPal.ExchangeRate.Sources.Coingecko
  alias BitPal.MockHTTPClient

  setup :verify_on_exit!

  @vs_currencies File.read!("test/bitpal/fixtures/coingecko_vs_currencies.json")
  @simple_price File.read!("test/bitpal/fixtures/coingecko_simple_price.json")

  test "supported" do
    MockHTTPClient
    |> expect(:request_body, fn _ ->
      {:ok, @vs_currencies}
    end)

    assert Coingecko.supported() == %{
             BCH: MapSet.new([:CAD, :EUR, :GBP, :JPY, :SEK, :USD]),
             LTC: MapSet.new([:CAD, :EUR, :GBP, :JPY, :SEK, :USD]),
             BTC: MapSet.new([:CAD, :EUR, :GBP, :JPY, :SEK, :USD]),
             DGC: MapSet.new([:CAD, :EUR, :GBP, :JPY, :SEK, :USD]),
             XMR: MapSet.new([:CAD, :EUR, :GBP, :JPY, :SEK, :USD])
           }
  end

  test "rates" do
    MockHTTPClient
    |> expect(:request_body, fn _ ->
      {:ok, @simple_price}
    end)

    assert Coingecko.rates(from: [:XMR, :BCH, :BTC], to: [:EUR, :USD, :SEK]) ==
             %{
               BCH: %{
                 EUR: Decimal.new("260.27"),
                 SEK: Decimal.new("2772.44"),
                 USD: Decimal.new("286.32")
               },
               BTC: %{
                 EUR: Decimal.new("35345"),
                 SEK: Decimal.new("376502"),
                 USD: Decimal.new("38882")
               },
               XMR: %{
                 EUR: Decimal.new("156.14"),
                 SEK: Decimal.new("1663.24"),
                 USD: Decimal.new("171.77")
               }
             }
  end
end
