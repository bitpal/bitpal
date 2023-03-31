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
    test "updates exchange rates", %{conn: conn, pair: pair} do
      rate1 = random_rate()
      ExchangeRates.update_exchange_rate(pair, rate1, :SEED, 10)

      rate2 = random_rate()
      ExchangeRates.update_exchange_rate(pair, rate2, :FACTORY, 1_000)

      {:ok, view, html} = live(conn, Routes.exchange_rate_path(conn, :show))

      assert html =~ rate1 |> Decimal.to_string(:normal)
      assert html =~ rate2 |> Decimal.to_string(:normal)

      rate3 = random_rate()
      ExchangeRates.update_exchange_rate(pair, rate3, :SEED, 10)
      assert render_eventually(view, rate3 |> Decimal.to_string(:normal))

      rate4 = random_rate()
      ExchangeRates.update_exchange_rate(pair, rate4, :FACTORY, 1_000)
      assert render_eventually(view, rate4 |> Decimal.to_string(:normal))
    end
  end
end
