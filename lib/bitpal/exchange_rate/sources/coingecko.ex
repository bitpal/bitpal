defmodule BitPal.ExchangeRate.Sources.Coingecko do
  @moduledoc """
  Source exchange rate data from Coingecko

  https://www.coingecko.com/en/api/documentation
  """

  @behaviour BitPal.ExchangeRate.Source

  alias BitPal.Currencies

  # No sane way of figuring this out automatically, so hardcode it is.
  @id_translation %{
    BCH: "bitcoin-cash",
    BTC: "bitcoin",
    DGC: "dogecoin",
    LTC: "litecoin",
    XMR: "monero"
  }
  @rev_id_translation Enum.reduce(@id_translation, %{}, fn {id, name}, acc ->
                        Map.put(acc, name, id)
                      end)

  @vs_currencies_url "https://api.coingecko.com/api/v3/simple/supported_vs_currencies"
  @simple_price_url "https://api.coingecko.com/api/v3/simple/price"

  @impl true
  def name, do: "Coingecko"

  @impl true
  def rate_limit_settings do
    %{
      timeframe: 1,
      timeframe_unit: :minutes,
      timeframe_max_requests: 50
    }
  end

  @impl true
  def supported do
    {:ok, body} = BitPalSettings.http_client().request_body(@vs_currencies_url)

    fiat =
      body
      |> Poison.decode!()
      |> Enum.reduce([], fn id, acc ->
        with {:ok, currency_id} <- Currencies.cast(id),
             false <- Currencies.is_crypto(currency_id) do
          [currency_id | acc]
        else
          _ -> acc
        end
      end)
      |> Enum.into(MapSet.new())

    Enum.reduce(@id_translation, %{}, fn {crypto_id, _}, acc ->
      Map.put(acc, crypto_id, fiat)
    end)
  end

  @impl true
  def request_type, do: :multi

  @impl true
  def rates(opts) do
    from = Keyword.fetch!(opts, :from)
    to = Keyword.fetch!(opts, :to)

    {:ok, body} = BitPalSettings.http_client().request_body(price_url(from, to))

    body
    |> Poison.decode!()
    |> Enum.reduce(%{}, fn {crypto_id, fiat}, acc ->
      fiat =
        Enum.reduce(fiat, %{}, fn {fiat_id, rate}, fiat_acc ->
          with {:ok, fiat_id} <- Currencies.cast(fiat_id),
               false <- Currencies.is_crypto(fiat_id),
               {:ok, rate} <- Decimal.cast(rate) do
            Map.put(fiat_acc, fiat_id, rate)
          else
            _ -> fiat_acc
          end
        end)

      Map.put(acc, Map.fetch!(@rev_id_translation, crypto_id), fiat)
    end)
  end

  defp price_url(ids, vs_currencies) when is_list(ids) and is_list(vs_currencies) do
    ids =
      ids
      |> Enum.map_join(",", fn id ->
        Map.fetch!(@id_translation, id)
      end)

    vs_currencies = Enum.join(vs_currencies, ",")

    "#{@simple_price_url}?ids=#{ids}&vs_currencies=#{vs_currencies}"
  end
end
