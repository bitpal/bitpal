defmodule BitPalApi.ExchangeRateController do
  use BitPalApi, :controller
  alias BitPal.ExchangeRates
  alias BitPalApi.ExchangeRateHandling

  def index(conn, _) do
    render(conn, "show.json", rates: ExchangeRates.all_exchange_rates())
  end

  def base(conn, %{"base" => base}) do
    rates = ExchangeRateHandling.fetch_with_base!(base)
    render(conn, "show.json", rates: rates)
  end

  def pair(conn, %{"base" => base, "quote" => xquote}) do
    rate = ExchangeRateHandling.fetch_with_pair!(base, xquote)
    render(conn, "show.json", rates: [rate])
  end
end
