defmodule BitPal.ExchangeRates do
  alias BitPal.ExchangeRateCache
  alias BitPal.ExchangeRateSupervisor

  @spec all_exchange_rates :: [ExchangeRate.t()]
  def all_exchange_rates do
    ExchangeRateSupervisor.cache_name()
    |> ExchangeRateCache.all_exchange_rates()
  end

  @spec fetch_exchange_rates_with_base(Currency.id()) :: [ExchangeRate.t()]
  def fetch_exchange_rates_with_base(base) do
    ExchangeRateSupervisor.cache_name()
    |> ExchangeRateCache.fetch_exchange_rates_with_base(base)
  end

  @spec fetch_exchange_rate(ExchangeRate.pair()) :: {:ok, ExchangeRate.t()} | :error
  def fetch_exchange_rate(pair) do
    ExchangeRateSupervisor.cache_name()
    |> ExchangeRateCache.fetch_exchange_rate(pair)
  end
end
