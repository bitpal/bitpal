defmodule BitPal.ExchangeRate.Sources.Coinbase do
  @moduledoc """
  Source exchange rate data from Coinbase

  https://developers.coinbase.com/api/v2
  """

  @behaviour BitPal.ExchangeRate.Source

  alias BitPal.Currencies

  @exchange_rates_url "https://api.coinbase.com/v2/exchange-rates?currency="

  @impl true
  def name, do: "Coinbase"

  @impl true
  def rate_limit_settings do
    %{
      timeframe: 1,
      timeframe_unit: :hours,
      timeframe_max_requests: 10_000
    }
  end

  @impl true
  def supported do
    data = fetch_exchange_rates("USD")

    {crypto, fiat} =
      data["data"]["rates"]
      |> Enum.reduce({[], []}, fn {currency, _rate}, acc = {crypto, fiat} ->
        case Currencies.cast(currency) do
          {:ok, currency_id} ->
            if Currencies.is_crypto(currency_id) do
              {[currency_id | crypto], fiat}
            else
              {crypto, [currency_id | fiat]}
            end

          :error ->
            acc
        end
      end)

    fiat = Enum.into(fiat, MapSet.new())

    Enum.reduce(crypto, %{}, fn crypto_id, acc ->
      Map.put(acc, crypto_id, fiat)
    end)
  end

  @impl true
  def request_type, do: :from

  @impl true
  def rates(opts) do
    from = Keyword.fetch!(opts, :from)
    data = fetch_exchange_rates(Atom.to_string(from))

    rates =
      data["data"]["rates"]
      |> Enum.reduce(%{}, fn {to, rate}, acc ->
        with {:ok, to} <- Currencies.cast(to),
             false <- Currencies.is_crypto(to),
             {:ok, rate} <- Decimal.cast(rate) do
          Map.put(acc, to, rate)
        else
          _ -> acc
        end
      end)

    %{from => rates}
  end

  defp fetch_exchange_rates(currency) do
    {:ok, body} = BitPalSettings.http_client().request_body(@exchange_rates_url <> currency)
    Poison.decode!(body)
  end
end
