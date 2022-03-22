defmodule BitPalWeb.ExchangeRateLiveTest do
  use BitPalWeb.ConnCase, integration: true, async: false
  alias BitPal.ExchangeRate.Sources.Empty
  alias BitPal.ExchangeRate.Sources.Random
  alias BitPal.ExchangeRateCache
  alias BitPal.ExchangeRateSupervisor

  setup tags do
    tags
    |> register_and_log_in_user()
    |> add_store()
  end

  describe "exchange rate updates" do
    test "updates exchange rates", %{conn: conn} do
      name = ExchangeRateSupervisor.cache_name()
      # ExchangeRateCache.delete_all(name)
      # Use a nonexistant fiat to avoid colliding with the random source.
      pair = {:BCH, :XXX}

      rate1 = cache_rate(pair: pair, source: Empty, prio: 10)
      ExchangeRateCache.update_exchange_rate(name, rate1)

      rate2 = cache_rate(pair: pair, source: Random, prio: 1_000)
      ExchangeRateCache.update_exchange_rate(name, rate2)

      {:ok, view, html} = live(conn, Routes.exchange_rate_path(conn, :show))

      assert html =~ rate1.rate.rate |> Decimal.to_string(:normal)
      assert html =~ rate2.rate.rate |> Decimal.to_string(:normal)

      rate3 = cache_rate(pair: pair, source: Empty, prio: 10)
      ExchangeRateCache.update_exchange_rate(name, rate3)

      assert render_eventually(view, rate3.rate.rate |> Decimal.to_string(:normal))

      rate4 = cache_rate(pair: pair, source: Random, prio: 1_000)
      ExchangeRateCache.update_exchange_rate(name, rate4)

      assert render_eventually(view, rate4.rate.rate |> Decimal.to_string(:normal))
    end
  end
end
