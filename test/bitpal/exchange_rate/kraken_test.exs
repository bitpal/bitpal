defmodule BitPal.ExchangeRate.KrakenTest do
  use ExUnit.Case, async: true
  alias BitPal.ExchangeRate
  alias BitPal.ExchangeRate.Kraken
  alias BitPal.ExchangeRateSupervisor.Result

  test "request and parse" do
    pair = {:BCH, :USD}

    assert Kraken.compute(pair, []) ==
             {:ok,
              %Result{
                rate: ExchangeRate.new!(Decimal.from_float(815.27), pair),
                backend: Kraken,
                score: 100
              }}
  end
end
