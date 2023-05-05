defmodule BitPalWeb.ExchangeRateLiveTest do
  use BitPalWeb.ConnCase, integration: false, async: true
  alias BitPal.ExchangeRates

  setup tags do
    tags
    |> register_and_log_in_user()
    |> add_store()
    |> Map.merge(rate_params(base: unique_currency_id()))
  end

  describe "exchange rate updates" do
    test "updates exchange rates", %{conn: conn, pair: pair = {base, xquote}} do
      rate1 = random_rate()
      ExchangeRates.update_exchange_rate(pair, rate1, :SEED, 10)

      rate2 = random_rate()
      ExchangeRates.update_exchange_rate(pair, rate2, :FACTORY, 1_000)

      {:ok, view, html} = live(conn, ~p"/rates")

      assert html =~ rate1 |> Decimal.to_string(:normal)
      assert html =~ rate2 |> Decimal.to_string(:normal)

      rate3 = random_rate()
      ExchangeRates.update_exchange_rate(pair, rate3, :SEED, 10)
      assert render_eventually(view, rate3 |> Decimal.to_string(:normal))

      # Adds in a new fiat for existing base
      rate4 = random_rate()
      rate5 = random_rate()

      ExchangeRates.update_exchange_rates(%{
        rates: %{base => %{unique_fiat() => rate4, unique_fiat() => rate5}},
        source: :FACTORY,
        prio: 1_000
      })

      assert render_eventually(view, rate4 |> Decimal.to_string(:normal))
      assert render_eventually(view, rate5 |> Decimal.to_string(:normal))

      # Adds in a new base
      rate6 = random_rate()
      ExchangeRates.update_exchange_rate({unique_currency_id(), xquote}, rate6, :FACTORY, 1_000)
      assert render_eventually(view, rate6 |> Decimal.to_string(:normal))
    end
  end
end
