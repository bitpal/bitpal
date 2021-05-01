defmodule BitPal.ExchangeRate.KrakenTest do
  use ExUnit.Case, async: true
  alias BitPal.ExchangeRate.Kraken
  alias BitPal.ExchangeRate.Result

  test "request and parse" do
    assert Kraken.compute({:bch, :usd}, []) ==
             {:ok,
              %Result{
                rate: Decimal.from_float(815.27),
                backend: Kraken,
                score: 100
              }}
  end
end
