defmodule BitPalFactory.ExchangeRateFactory do
  import BitPalFactory.UtilFactory
  alias BitPalFactory.CurrencyFactory
  alias BitPal.ExchangeRate
  alias BitPalSchemas.InvoiceRates

  def random_rate(opts \\ []) do
    decimals = Keyword.get(opts, :decimals, 3)
    rand_pos_decimal(decimals: decimals)
  end

  @spec pair(keyword) :: ExchangeRate.pair()
  def pair(opts \\ []) do
    {opts[:base] || CurrencyFactory.crypto_currency_id(),
     opts[:quote] || CurrencyFactory.fiat_currency_id()}
  end

  @spec rate_params(keyword) :: map
  def rate_params(opts \\ []) do
    %{
      pair: opts[:pair] || pair(opts),
      prio: opts[:prio] || Faker.random_between(0, 100),
      source: opts[:source] || :FACTORY,
      rate: opts[:rate] || random_rate(opts)
    }
  end

  @spec bundled_rates(keyword) :: InvoiceRates.t()
  def bundled_rates(opts \\ []) do
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
          Map.put(acc, fiat_id, random_rate(opts))
        end)
      )
    end)
  end
end
