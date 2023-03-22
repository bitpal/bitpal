defmodule BitPal.ExchangeRates do
  alias BitPal.ExchangeRate
  alias BitPal.ExchangeRateCache
  alias BitPal.ExchangeRateSupervisor
  alias BitPalSchemas.Currency

  @spec all_exchange_rates :: [ExchangeRate.t()]
  def all_exchange_rates do
    ExchangeRateSupervisor.cache_name()
    |> ExchangeRateCache.all_exchange_rates()
  end

  @spec fetch_exchange_rate(ExchangeRate.pair()) :: {:ok, ExchangeRate.t()} | :error
  def fetch_exchange_rate(pair) do
    ExchangeRateSupervisor.cache_name()
    |> ExchangeRateCache.fetch_exchange_rate(pair)
  end

  @spec all_raw_exchange_rates :: [ExchangeRateCache.Rate.t()]
  def all_raw_exchange_rates do
    ExchangeRateSupervisor.cache_name()
    |> ExchangeRateCache.all_raw_exchange_rates()
  end

  @spec fetch_raw_exchange_rates(ExchangeRate.pair()) ::
          {:ok, [ExchangeRateCache.Rate.t()]} | :error
  def fetch_raw_exchange_rates(pair) do
    ExchangeRateSupervisor.cache_name()
    |> ExchangeRateCache.fetch_raw_exchange_rates(pair)
  end

  @spec fetch_exchange_rates_with_base(Currency.id()) :: [ExchangeRate.t()]
  def fetch_exchange_rates_with_base(base) do
    all_exchange_rates()
    |> Enum.filter(fn
      %ExchangeRate{pair: {^base, _}} -> true
      _ -> false
    end)
  end

  @spec fetch_exchange_rates_with_quote(Currency.id()) :: [ExchangeRate.t()]
  def fetch_exchange_rates_with_quote(xquote) do
    all_exchange_rates()
    |> Enum.filter(fn
      %ExchangeRate{pair: {_, ^xquote}} -> true
      _ -> false
    end)
  end

  @spec fetch_exchange_rates(Currency.id(), Currency.id()) :: [ExchangeRate.t()]
  def fetch_exchange_rates(base, nil) do
    fetch_exchange_rates_with_base(base)
  end

  def fetch_exchange_rates(nil, xquote) do
    fetch_exchange_rates_with_quote(xquote)
  end

  def fetch_exchange_rates(base, xquote) do
    case fetch_exchange_rate({base, xquote}) do
      {:ok, rate} -> [rate]
      _ -> []
    end
  end
end
