defmodule BitPalApi.ExchangeRateJSON do
  use BitPalApi, :json
  alias BitPalSchemas.InvoiceRates

  def show(%{rates: rates}) when is_list(rates) do
    show(%{rates: InvoiceRates.bundle_rates(rates)})
  end

  def show(%{rates: rates}) when is_map(rates) do
    rates
    |> InvoiceRates.to_float()
  end

  def show(%{rate: rate}) do
    show(%{rates: [rate]})
  end
end
