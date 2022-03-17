defmodule BitPal.ExchangeRate.KrakenTest do
  use ExUnit.Case, async: true
  import Mox
  alias BitPal.ExchangeRate.Sources.Kraken
  alias BitPal.MockHTTPClient

  setup :verify_on_exit!

  @bcheur File.read!("test/bitpal/fixtures/kraken_bcheur.json")
  @xmreur File.read!("test/bitpal/fixtures/kraken_xmreur.json")
  @asset_pairs File.read!("test/bitpal/fixtures/kraken_asset_pairs.json")

  test "supported" do
    MockHTTPClient
    |> expect(:request_body, fn _ ->
      {:ok, @asset_pairs}
    end)

    assert Kraken.supported() ==
             %{
               BCH: MapSet.new([:AUD, :EUR, :GBP, :JPY, :USD]),
               LTC: MapSet.new([:AUD, :EUR, :GBP, :JPY, :USD]),
               XMR: MapSet.new([:EUR, :USD])
             }
  end

  test "bcheur rates" do
    MockHTTPClient
    |> expect(:request_body, fn _ ->
      {:ok, @bcheur}
    end)

    assert Kraken.rates(pair: {:BCH, :EUR}) == %{BCH: %{EUR: Decimal.new("741.620000")}}
  end

  test "xmreur rates" do
    MockHTTPClient
    |> expect(:request_body, fn _ ->
      {:ok, @xmreur}
    end)

    assert Kraken.rates(pair: {:XMR, :EUR}) == %{XMR: %{EUR: Decimal.new("165.45000000")}}
  end
end
