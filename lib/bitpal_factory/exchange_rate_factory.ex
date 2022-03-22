defmodule BitPalFactory.ExchangeRateFactory do
  import BitPalFactory.UtilFactory
  alias BitPal.ExchangeRate
  alias BitPal.ExchangeRateCache

  @spec pair(keyword) :: ExchangeRate.pair()
  def pair(opts \\ []) do
    {opts[:base] || :BCH, opts[:quote] || :USD}
  end

  @spec exchange_rate(keyword) :: ExchangeRate.t()
  def exchange_rate(opts \\ []) do
    %ExchangeRate{
      pair: opts[:pair] || pair(opts),
      rate: opts[:rate] || rand_decimal()
    }
  end

  @spec cache_rate(keyword) :: ExchangeRateCache.Rate.t()
  def cache_rate(opts \\ []) do
    %ExchangeRateCache.Rate{
      prio: opts[:prio] || Faker.random_between(0, 100),
      source: opts[:source] || :NO_SRC,
      rate: opts[:exchange_rate] || exchange_rate(opts),
      updated: opts[:updated] || NaiveDateTime.utc_now()
    }
  end
end
