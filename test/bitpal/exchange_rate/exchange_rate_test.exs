defmodule BitPal.ExchangeRateTest do
  use BitPal.DataCase, async: true
  alias BitPalSchemas.ExchangeRate
  alias BitPal.ExchangeRates
  alias BitPal.ExchangeRateEvents
  alias BitPalSettings.ExchangeRateSettings

  setup tags do
    if tags[:subscribe] do
      ExchangeRateEvents.subscribe()
      ExchangeRateEvents.subscribe_raw()
    end

    rate_params(base: unique_currency_id(), quote: unique_fiat(), source: :RATE_TEST)
  end

  describe "update rate" do
    @tag subscribe: true
    test "insert new", %{pair: pair = {base, xquote}, source: source, prio: prio} do
      rate = Decimal.from_float(1.0)

      ExchangeRates.update_exchange_rate(pair, rate, source, prio)

      assert {:ok,
              %ExchangeRate{
                rate: ^rate,
                base: ^base,
                quote: ^xquote,
                source: ^source,
                prio: ^prio
              }} = ExchangeRates.fetch_exchange_rate(pair)

      assert_receive {{:exchange_rate, :update},
                      %ExchangeRate{
                        rate: ^rate
                      }}

      assert_receive {{:exchange_rate, :raw_update},
                      %ExchangeRate{
                        rate: ^rate
                      }}
    end

    @tag subscribe: true
    test "replace old rate", %{pair: pair = {base, xquote}, source: source, prio: prio} do
      rate = Decimal.from_float(1.0)
      ExchangeRates.update_exchange_rate(pair, rate, source, prio)

      assert {:ok, %ExchangeRate{rate: ^rate}} = ExchangeRates.fetch_exchange_rate(pair)

      # pair + source should be unique, so this should replace the existing rate.
      new_rate = Decimal.from_float(2.0)
      lower_prio = prio - 1
      assert ExchangeRates.update_exchange_rate(pair, new_rate, source, lower_prio)

      assert {:ok,
              %ExchangeRate{
                rate: ^new_rate,
                base: ^base,
                quote: ^xquote,
                source: ^source,
                prio: ^lower_prio
              }} = ExchangeRates.fetch_exchange_rate(pair)

      assert_receive {{:exchange_rate, :update}, %ExchangeRate{rate: ^rate}}
      assert_receive {{:exchange_rate, :raw_update}, %ExchangeRate{rate: ^rate}}
    end

    @tag subscribe: true
    test "replace a lower prio rate", %{pair: pair} do
      rate1 = Decimal.from_float(1.0)
      rate2 = Decimal.from_float(2.0)

      ExchangeRates.update_exchange_rate(pair, rate1, :SRC_1, 10)
      assert_receive {{:exchange_rate, :update}, %ExchangeRate{rate: ^rate1}}
      ExchangeRates.update_exchange_rate(pair, rate2, :SRC_2, 20)
      assert_receive {{:exchange_rate, :update}, %ExchangeRate{rate: ^rate2}}

      assert {:ok, %ExchangeRate{rate: ^rate2}} = ExchangeRates.fetch_exchange_rate(pair)

      # We update the lower prio rate, which should not be generally visible.
      rate3 = Decimal.from_float(3.0)
      ExchangeRates.update_exchange_rate(pair, rate3, :SRC_1, 10)
      assert_receive {{:exchange_rate, :raw_update}, %ExchangeRate{rate: ^rate3}}
      refute_receive {{:exchange_rate, :update}, %ExchangeRate{rate: ^rate3}}

      assert {:ok, %ExchangeRate{rate: ^rate2}} = ExchangeRates.fetch_exchange_rate(pair)
    end
  end

  describe "filter antiquated" do
    test "new source with higher prio replaces", %{pair: pair, source: source, prio: prio} do
      rate = Decimal.from_float(1.0)
      ExchangeRates.update_exchange_rate(pair, rate, source, prio)

      assert {:ok, %ExchangeRate{rate: ^rate}} = ExchangeRates.fetch_exchange_rate(pair)

      # Inserting a new source with a higher prio should replace the above
      rate2 = Decimal.from_float(2.0)
      prio2 = prio + 1
      source2 = :RATE_TEST_2
      assert ExchangeRates.update_exchange_rate(pair, rate2, source2, prio2)

      assert {:ok,
              %ExchangeRate{
                rate: ^rate2,
                source: ^source2,
                prio: ^prio2
              }} = ExchangeRates.fetch_exchange_rate(pair)
    end

    test "multiple different rates", %{pair: {base, f1}, source: source1} do
      source2 = :RATE_TEST_2
      f2 = unique_fiat()

      ExchangeRates.update_exchange_rate({base, f1}, Decimal.from_float(1.0), source1, 10)
      ExchangeRates.update_exchange_rate({base, f1}, Decimal.from_float(2.0), source2, 20)

      ExchangeRates.update_exchange_rate({base, f2}, Decimal.from_float(3.0), source2, 30)
      ExchangeRates.update_exchange_rate({base, f2}, Decimal.from_float(4.0), source1, 40)

      rates =
        ExchangeRates.fetch_exchange_rates_with_base(base)
        |> Enum.sort_by(fn rate -> rate.prio end, :desc)

      dec4 = Decimal.from_float(4.0)
      dec2 = Decimal.from_float(2.0)

      assert [
               %ExchangeRate{prio: 40, rate: ^dec4, source: ^source1},
               %ExchangeRate{prio: 20, rate: ^dec2, source: ^source2}
             ] = rates

      rates =
        ExchangeRates.fetch_exchange_rates_with_quote(f1)
        |> Enum.sort_by(fn rate -> rate.prio end, :desc)

      assert [
               %ExchangeRate{prio: 20, rate: ^dec2, source: ^source2}
             ] = rates

      rates =
        ExchangeRates.all_exchange_rates()
        |> Enum.filter(fn
          %ExchangeRate{base: ^base} -> true
          _ -> false
        end)
        |> Enum.sort_by(fn rate -> rate.prio end, :desc)

      assert [
               %ExchangeRate{prio: 40, rate: ^dec4, source: ^source1},
               %ExchangeRate{prio: 20, rate: ^dec2, source: ^source2}
             ] = rates
    end
  end

  test "many mixed rates", %{pair: pair = {base, xquote}} do
    ExchangeRates.update_exchange_rate(pair, Decimal.from_float(1.0), :SRC_1, 10)
    ExchangeRates.update_exchange_rate(pair, Decimal.from_float(2.0), :SRC_2, 20)
    ExchangeRates.update_exchange_rate(pair, Decimal.from_float(3.0), :SRC_3, 30)

    other_fiat = unique_fiat()
    assert base != :BCH
    assert other_fiat != xquote
    ExchangeRates.update_exchange_rate({base, other_fiat}, Decimal.from_float(0.1), :SRC_01, 40)
    ExchangeRates.update_exchange_rate({:BCH, xquote}, Decimal.from_float(0.1), :SRC_01, 40)
    ExchangeRates.update_exchange_rate({:BCH, other_fiat}, Decimal.from_float(0.1), :SRC_01, 40)

    dec3 = Decimal.from_float(3.0)
    dec01 = Decimal.from_float(0.1)

    assert [
             %ExchangeRate{
               base: ^base,
               quote: ^other_fiat,
               rate: ^dec01,
               source: :SRC_01,
               prio: 40
             },
             %ExchangeRate{
               base: ^base,
               quote: ^xquote,
               rate: ^dec3,
               source: :SRC_3,
               prio: 30
             }
           ] =
             ExchangeRates.fetch_exchange_rates_with_base(base)
             |> Enum.sort_by(& &1.prio, :desc)

    # Update lowest prio
    ExchangeRates.update_exchange_rate(pair, Decimal.from_float(11.0), :SRC_1, 10)

    assert {:ok,
            %ExchangeRate{
              base: ^base,
              quote: ^xquote,
              rate: ^dec3,
              source: :SRC_3,
              prio: 30
            }} = ExchangeRates.fetch_exchange_rate(pair)

    # Update middle prio
    ExchangeRates.update_exchange_rate(pair, Decimal.from_float(12.0), :SRC_2, 20)

    assert {:ok,
            %ExchangeRate{
              base: ^base,
              quote: ^xquote,
              rate: ^dec3,
              source: :SRC_3,
              prio: 30
            }} = ExchangeRates.fetch_exchange_rate(pair)

    # Update highest prio
    dec13 = Decimal.from_float(13.0)
    ExchangeRates.update_exchange_rate(pair, dec13, :SRC_3, 30)

    assert {:ok,
            %ExchangeRate{
              base: ^base,
              quote: ^xquote,
              rate: ^dec13,
              source: :SRC_3,
              prio: 30
            }} = ExchangeRates.fetch_exchange_rate(pair)

    assert [
             %ExchangeRate{
               base: ^base,
               quote: ^other_fiat,
               rate: ^dec01,
               source: :SRC_01,
               prio: 40
             },
             %ExchangeRate{
               base: ^base,
               quote: ^xquote,
               rate: ^dec13,
               source: :SRC_3,
               prio: 30
             }
           ] =
             ExchangeRates.fetch_exchange_rates_with_base(base)
             |> Enum.sort_by(& &1.prio, :desc)

    assert [
             %ExchangeRate{
               base: :BCH,
               quote: ^xquote,
               rate: ^dec01,
               source: :SRC_01,
               prio: 40
             },
             %ExchangeRate{
               base: ^base,
               quote: ^xquote,
               rate: ^dec13,
               source: :SRC_3,
               prio: 30
             }
           ] =
             ExchangeRates.fetch_exchange_rates_with_quote(xquote)
             |> Enum.sort_by(& &1.prio, :desc)
  end

  test "filters old rates", %{rate: rate, pair: pair = {base, xquote}, source: source, prio: prio} do
    now = NaiveDateTime.utc_now()
    ttl = ExchangeRateSettings.rates_ttl()

    expired =
      NaiveDateTime.add(now, -ttl - 1, :millisecond)
      |> NaiveDateTime.truncate(:second)

    %ExchangeRate{
      updated_at: expired,
      rate: rate,
      base: base,
      quote: xquote,
      source: source,
      prio: prio
    }
    |> Repo.insert!()

    assert ExchangeRates.fetch_exchange_rate(pair) == {:error, :not_found}
    assert ExchangeRates.fetch_exchange_rates_with_base(base) == []

    # Need to filter out seeded currencies and things from other tests.
    assert ExchangeRates.fetch_exchange_rates_with_quote(xquote)
           |> filter_source(source)

    assert ExchangeRates.all_exchange_rates()
           |> filter_source(source) == []

    assert ExchangeRates.all_unprioritized_exchange_rates()
           |> filter_source(source) == []

    assert ExchangeRates.fetch_unprioritized_exchange_rates(pair)
           |> filter_source(source) == []
  end

  defp filter_source(rates, sources) when is_list(sources) do
    allowed = MapSet.new(sources)

    rates
    |> Enum.filter(fn rate -> MapSet.member?(allowed, rate.source) end)
  end

  defp filter_source(rates, source) do
    filter_source(rates, [source])
  end
end
