defmodule BitPal.ExchangeRateCacheTest do
  use ExUnit.Case, async: true
  use BitPal.CaseHelpers
  alias BitPal.ExchangeRateCache
  alias BitPal.ExchangeRateEvents
  alias BitPalSettings.ExchangeRateSettings

  setup tags do
    if tags[:no_server] do
      tags
    else
      name = unique_server_name()
      start_supervised!({ExchangeRateCache, name: name})
      %{name: name}
    end
  end

  describe "cache" do
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
      ExchangeRateEvents.subscribe_raw()

      # First will be updated
      ExchangeRateCache.update_exchange_rate(name, rate2)
      assert ExchangeRateCache.fetch_raw_exchange_rate(name, pair) == {:ok, rate2}
      rate = rate2.rate
      assert_received {{:exchange_rate, :raw_update}, ^pair}
      assert_received {{:exchange_rate, :update}, ^rate}

      # Lower prio will not override
      ExchangeRateCache.update_exchange_rate(name, rate1)
      assert ExchangeRateCache.fetch_raw_exchange_rate(name, pair) == {:ok, rate2}
      rate = rate1.rate
      assert_received {{:exchange_rate, :raw_update}, ^pair}
      refute_received {{:exchange_rate, :update}, ^rate}

      # Higher prio will override
      ExchangeRateCache.update_exchange_rate(name, rate3)
      assert ExchangeRateCache.fetch_raw_exchange_rate(name, pair) == {:ok, rate3}
      rate = rate3.rate
      assert_received {{:exchange_rate, :raw_update}, ^pair}
      assert_received {{:exchange_rate, :update}, ^rate}

      assert ExchangeRateCache.fetch_raw_exchange_rates(name, pair) ==
               {:ok, [rate3, rate2, rate1]}
    end

    test "replaces", %{name: name} do
      pair = pair()
      rate1 = cache_rate(prio: 10, pair: pair, source: :ONE)
      rate2 = cache_rate(prio: 20, pair: pair, source: :TWO)
      rate3 = cache_rate(prio: 30, pair: pair, source: :THREE)

      ExchangeRateEvents.subscribe()
      ExchangeRateEvents.subscribe_raw()

      ExchangeRateCache.update_exchange_rate(name, rate1)
      ExchangeRateCache.update_exchange_rate(name, rate2)
      ExchangeRateCache.update_exchange_rate(name, rate3)
      assert_received {{:exchange_rate, :update}, %{pair: ^pair}}

      rate1_2 = cache_rate(prio: 10, pair: pair, source: :ONE)
      rate2_2 = cache_rate(prio: 20, pair: pair, source: :TWO)
      rate3_2 = cache_rate(prio: 30, pair: pair, source: :THREE)

      ExchangeRateCache.update_exchange_rate(name, rate1_2)
      rate = rate1_2.rate
      assert_received {{:exchange_rate, :raw_update}, ^pair}
      refute_received {{:exchange_rate, :update}, ^rate}

      ExchangeRateCache.update_exchange_rate(name, rate2_2)
      rate = rate2_2.rate
      assert_received {{:exchange_rate, :raw_update}, ^pair}
      refute_received {{:exchange_rate, :update}, ^rate}

      ExchangeRateCache.update_exchange_rate(name, rate3_2)
      rate = rate3_2.rate
      assert_received {{:exchange_rate, :raw_update}, ^pair}
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

  describe "expired" do
    @tag no_server: true
    test "expired?" do
      now = NaiveDateTime.utc_now()
      ttl = 1_000
      valid = NaiveDateTime.add(now, -ttl, :millisecond)
      expired = NaiveDateTime.add(now, -ttl - 1, :millisecond)
      assert ExchangeRateCache.expired?(cache_rate(updated: expired), now, ttl)
      assert not ExchangeRateCache.expired?(cache_rate(updated: valid), now, ttl)
      assert not ExchangeRateCache.expired?(cache_rate(updated: now), now, ttl)
    end

    @tag no_server: true
    test "filter expired" do
      now = NaiveDateTime.utc_now()
      ttl = 1_000
      valid_rate = cache_rate(updated: NaiveDateTime.add(now, -ttl, :millisecond))
      expired_rate = cache_rate(updated: NaiveDateTime.add(now, -ttl - 1, :millisecond))

      assert ExchangeRateCache.filter_expired([valid_rate, expired_rate], now, ttl) == [
               valid_rate
             ]
    end
  end

  describe "cached expired handling" do
    setup %{name: name} do
      pair = {:BCH, :EUR}
      now = NaiveDateTime.utc_now()
      ttl = ExchangeRateSettings.rates_ttl()

      valid_rate =
        cache_rate(
          pair: pair,
          updated: now,
          prio: 10,
          source: :one
        )

      expired_rate =
        cache_rate(
          pair: pair,
          updated: NaiveDateTime.add(now, -ttl - 1, :millisecond),
          prio: 100,
          source: :two
        )

      ExchangeRateCache.update_exchange_rate(name, valid_rate)
      ExchangeRateCache.update_exchange_rate(name, expired_rate)

      %{name: name, pair: pair, valid_rate: valid_rate, expired_rate: expired_rate}
    end

    test "fetch filters expired", %{
      name: name,
      pair: pair,
      valid_rate: valid_rate
    } do
      assert ExchangeRateCache.fetch_raw_exchange_rate(name, pair) == {:ok, valid_rate}
    end

    test "fetch all filters expired", %{
      name: name,
      valid_rate: valid_rate
    } do
      assert ExchangeRateCache.all_raw_exchange_rates(name) == [valid_rate]
    end

    test "updates deletes expired", %{
      name: name,
      pair: pair,
      valid_rate: valid_rate
    } do
      new_rate = cache_rate(pair: pair, prio: 50, source: :three)
      ExchangeRateCache.update_exchange_rate(name, new_rate)

      assert [{_, [^new_rate, ^valid_rate]}] = BitPal.Cache.all(name)
    end
  end
end
