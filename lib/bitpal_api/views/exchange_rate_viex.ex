defmodule BitPalApi.ExchangeRateView do
  use BitPalApi, :view
  alias BitPalSchemas.InvoiceRates

  def render("show.json", %{rates: rates}) do
    InvoiceRates.bundle_rates(rates)
    |> InvoiceRates.to_float()
  end
end
