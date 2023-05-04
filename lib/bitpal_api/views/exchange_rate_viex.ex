defmodule BitPalApi.ExchangeRateView do
  use BitPalApi, :view
  alias BitPalSchemas.InvoiceRates

  def render(target, %{rates: rates}) when is_list(rates) do
    render(target, %{rates: InvoiceRates.bundle_rates(rates)})
  end

  def render("show.json", %{rates: rates}) when is_map(rates) do
    rates
    |> InvoiceRates.to_float()
  end
end
