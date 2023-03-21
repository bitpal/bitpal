defmodule BitPalApi.ExchangeRateView do
  use BitPalApi, :view
  alias BitPal.ExchangeRate
  alias BitPalSchemas.Currency

  def render("show.json", %{rates: rates}) do
    bundle_rates(rates)
  end

  @spec bundle_rates([ExchangeRate.t()]) :: %{Currency.t() => %{Currency.t() => float}}
  defp bundle_rates(rates) do
    # Transforms a list of exchange rates into a map of maps, like so:
    #
    # %{
    #   base_currency => %{
    #     c0 => 1.0,
    #     c1 => 2.3
    #   }, ...
    # }
    #
    rates
    |> Enum.group_by(
      fn %ExchangeRate{pair: {base, _}} -> base end,
      fn v -> v end
    )
    |> Enum.map(fn {base, quotes} ->
      {base,
       Enum.map(quotes, fn rate ->
         {ExchangeRate.currency(rate), Decimal.to_float(rate.rate)}
       end)
       |> Map.new()}
    end)
    |> Map.new()
  end
end
