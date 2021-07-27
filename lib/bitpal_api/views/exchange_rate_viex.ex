defmodule BitPalApi.ExchangeRateView do
  use BitPalApi, :view
  alias BitPal.ExchangeRate

  def render("index.json", %{rates: rates}) do
    Enum.map(rates, fn rate -> render("show.json", rate: rate) end)
  end

  def render("show.json", %{rate: rate = %ExchangeRate{}}) do
    currency = ExchangeRate.currency(rate)

    %{
      code: Atom.to_string(currency),
      name: Money.Currency.name(currency),
      rate: rate.rate
    }
  end

  def render("rate_response.json", %{rate: rate = %ExchangeRate{pair: {from, to}}}) do
    %{
      pair: "#{from}-#{to}",
      rate: rate.rate
    }
  end
end
