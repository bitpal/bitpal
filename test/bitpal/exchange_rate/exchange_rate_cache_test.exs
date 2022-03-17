defmodule BitPal.ExchangeRateCacheTest do
  use ExUnit.Case, async: true
  use BitPal.CaseHelpers
  alias BitPal.ExchangeRateCache
  alias BitPal.ExchangeRateEvents

  setup _tags do
    name = unique_server_name()
    start_supervised!({ExchangeRateCache, name: name})
    %{name: name}
  end

  test "put first", %{name: name} do
    rate = cache_rate()

    ExchangeRateCache.update_exchange_rate(name, rate)

    assert ExchangeRateCache.fetch_raw_exchange_rate(name, rate.rate.pair) == {:ok, rate}
    assert ExchangeRateCache.fetch_exchange_rate(name, rate.rate.pair) == {:ok, rate.rate}
  end

  test "put duplicate with prio", %{name: name} do
    pair = pair()
    rate1 = cache_rate(prio: 10, pair: pair, source: :ONE)
    rate2 = cache_rate(prio: 20, pair: pair, source: :TWO)
    rate3 = cache_rate(prio: 30, pair: pair, source: :THREE)

    ExchangeRateEvents.subscribe()

    # First will be updated
    ExchangeRateCache.update_exchange_rate(name, rate2)
    assert ExchangeRateCache.fetch_raw_exchange_rate(name, pair) == {:ok, rate2}
    rate = rate2.rate
    assert_received {{:exchange_rate, :update}, ^rate}

    # Lower prio will not override
    ExchangeRateCache.update_exchange_rate(name, rate1)
    assert ExchangeRateCache.fetch_raw_exchange_rate(name, pair) == {:ok, rate2}
    rate = rate1.rate
    refute_received {{:exchange_rate, :update}, ^rate}

    # Higher prio will override
    ExchangeRateCache.update_exchange_rate(name, rate3)
    assert ExchangeRateCache.fetch_raw_exchange_rate(name, pair) == {:ok, rate3}
    rate = rate3.rate
    assert_received {{:exchange_rate, :update}, ^rate}

    assert ExchangeRateCache.fetch_raw_exchange_rates(name, pair) == {:ok, [rate3, rate2, rate1]}
  end

  test "replaces", %{name: name} do
    pair = pair()
    rate1 = cache_rate(prio: 10, pair: pair, source: :ONE)
    rate2 = cache_rate(prio: 20, pair: pair, source: :TWO)
    rate3 = cache_rate(prio: 30, pair: pair, source: :THREE)

    ExchangeRateEvents.subscribe()

    ExchangeRateCache.update_exchange_rate(name, rate1)
    ExchangeRateCache.update_exchange_rate(name, rate2)
    ExchangeRateCache.update_exchange_rate(name, rate3)
    assert_received {{:exchange_rate, :update}, %{pair: ^pair}}

    rate1_2 = cache_rate(prio: 10, pair: pair, source: :ONE)
    rate2_2 = cache_rate(prio: 20, pair: pair, source: :TWO)
    rate3_2 = cache_rate(prio: 30, pair: pair, source: :THREE)

    ExchangeRateCache.update_exchange_rate(name, rate1_2)
    rate = rate1_2.rate
    refute_received {{:exchange_rate, :update}, ^rate}

    ExchangeRateCache.update_exchange_rate(name, rate2_2)
    rate = rate2_2.rate
    refute_received {{:exchange_rate, :update}, ^rate}

    ExchangeRateCache.update_exchange_rate(name, rate3_2)
    rate = rate3_2.rate
    assert_received {{:exchange_rate, :update}, ^rate}

    assert ExchangeRateCache.fetch_raw_exchange_rates(name, pair) ==
             {:ok, [rate3_2, rate2_2, rate1_2]}
  end

  test "get all", %{name: name} do
    pair1 = {:BCH, :EUR}
    rate1 = cache_rate(prio: 10, pair: pair1, source: :ONE)
    rate2 = cache_rate(prio: 20, pair: pair1, source: :TWO)

    rate3 = cache_rate(pair: {:BTC, :USD}, source: :THREE)

    ExchangeRateCache.update_exchange_rate(name, rate1)
    ExchangeRateCache.update_exchange_rate(name, rate2)
    ExchangeRateCache.update_exchange_rate(name, rate3)

    expected =
      [rate1.rate, rate2.rate, rate3.rate]
      |> MapSet.new()

    assert ExchangeRateCache.all_exchange_rates(name) |> MapSet.new() ==
             expected
  end

  test "get all raw", %{name: name} do
    pair1 = {:BCH, :EUR}
    rate1 = cache_rate(prio: 10, pair: pair1, source: :ONE)
    rate2 = cache_rate(prio: 20, pair: pair1, source: :TWO)

    rate3 = cache_rate(pair: {:BTC, :USD}, source: :THREE)

    ExchangeRateCache.update_exchange_rate(name, rate1)
    ExchangeRateCache.update_exchange_rate(name, rate2)
    ExchangeRateCache.update_exchange_rate(name, rate3)

    expected = [rate1, rate2, rate3] |> MapSet.new()

    assert ExchangeRateCache.all_raw_exchange_rates(name) |> MapSet.new() ==
             expected
  end
end
