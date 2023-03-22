defmodule BitPalFactory.ExchangeRateFactory do
  import BitPalFactory.UtilFactory
  alias BitPal.ExchangeRate
  alias BitPal.ExchangeRateCache
  alias BitPalSchemas.InvoiceRates

  @spec pair(keyword) :: ExchangeRate.pair()
  def pair(opts \\ []) do
    {opts[:base] || :BCH, opts[:quote] || :USD}
  end

  @spec exchange_rate(keyword) :: ExchangeRate.t()
  def exchange_rate(opts \\ []) do
    %ExchangeRate{
      pair: opts[:pair] || pair(opts),
      rate: opts[:rate] || rand_pos_decimal(decimals: 3)
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

  @spec bundled_rates(keyword) :: InvoiceRates.t()
  def bundled_rates(opts \\ []) do
    decimals = Keyword.get(opts, :decimals, 3)

    fiat =
      case Keyword.get(opts, :fiat) do
        nil -> [:USD, :EUR, :SEK]
        x when is_list(x) -> x
        x when is_atom(x) -> [x]
      end
      |> MapSet.new()

    crypto =
      case Keyword.get(opts, :crypto) do
        nil -> [:BCH, :XMR, :DGC]
        x when is_list(x) -> x
        x when is_atom(x) -> [x]
      end
      |> MapSet.new()

    Enum.reduce(crypto, %{}, fn crypto_id, acc ->
      Map.put(
        acc,
        crypto_id,
        Enum.reduce(fiat, %{}, fn fiat_id, acc ->
          Map.put(acc, fiat_id, rand_pos_decimal(decimals: decimals))
        end)
      )
    end)
  end
end
