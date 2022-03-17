defmodule BitPalApi.ExchangeRateView do
  use BitPalApi, :view
  alias BitPal.ExchangeRate

  def render("index.json", %{rates: rates}) do
    Enum.map(rates, fn {base, rates} ->
      render("show.json", base: base, rates: rates)
    end)
  end

  def render("show.json", %{base: base, rates: rates}) do
    %{
      base: base,
      rates:
        Enum.reduce(rates, %{}, fn %ExchangeRate{rate: rate, pair: {^base, xquote}}, acc ->
          Map.put(acc, xquote, rate)
        end)
    }
  end

  def render("show.json", %{rate: %ExchangeRate{rate: rate, pair: {base, xquote}}}) do
    %{
      base: Atom.to_string(base),
      quote: Atom.to_string(xquote),
      rate: rate
    }
  end
end
