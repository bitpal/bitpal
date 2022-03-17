defmodule BitPalFactory.ExchangeRateFactory do
  import BitPalFactory.UtilFactory
  alias BitPalFactory.CurrencyFactory
  alias BitPal.ExchangeRate
  alias BitPal.ExchangeRateCache

  # @spec unique_pair :: ExchangeRate.pair()
  # def unique_pair do
  #   {CurrencyFactory.unique_currency_id(), CurrencyFactory.fiat_currency_id()}
  # end

  @spec pair(keyword) :: ExchangeRate.pair()
  def pair(opts \\ []) do
    # FIXME should these be randomized too?
    {opts[:from] || :BCH, opts[:to] || :USD}
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
