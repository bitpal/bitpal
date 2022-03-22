defmodule BitPal.ExchangeRate.CoinbaseTest do
  use ExUnit.Case, async: true
  import Mox
  alias BitPal.ExchangeRate.Sources.Coinbase
  alias BitPal.MockHTTPClient

  setup :verify_on_exit!

  @usd_response File.read!("test/bitpal/fixtures/coinbase_exchange_rates.json")
  @bch_response File.read!("test/bitpal/fixtures/coinbase_exchange_rates_bch.json")

  test "supported" do
    MockHTTPClient
    |> expect(:request_body, fn _ ->
      {:ok, @usd_response}
    end)

    assert Coinbase.supported() == %{
             BCH: MapSet.new([:CAD, :ERN, :EUR, :GBP, :JPY, :SEK, :USD]),
             LTC: MapSet.new([:CAD, :ERN, :EUR, :GBP, :JPY, :SEK, :USD]),
             BTC: MapSet.new([:CAD, :ERN, :EUR, :GBP, :JPY, :SEK, :USD])
           }
  end

  test "rates" do
    MockHTTPClient
    |> expect(:request_body, fn _ ->
      {:ok, @bch_response}
    end)

    assert Coinbase.rates(base: :BCH) == %{
             BCH: %{
               CAD: Decimal.new("370.8517631"),
               EUR: Decimal.new("264.74"),
               SEK: Decimal.new("2811.94160067"),
               USD: Decimal.new("290.47")
             }
           }
  end
end
