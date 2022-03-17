defmodule BitPal.ExchangeRate.Sources.Random do
  @behaviour BitPal.ExchangeRate.Source

  alias BitPal.Currencies
  alias BitPalFactory.UtilFactory
  alias BitPalSettings.ExchangeRateSettings

  @impl true
  def rate_limit_settings do
    %{
      timeframe: 10,
      timeframe_max_requests: 10,
      timeframe_unit: :milliseconds
    }
  end

  @impl true
  def name, do: "Random"

  @impl true
  def supported do
    fiat = ExchangeRateSettings.fiat_to_update() |> MapSet.new()

    Enum.reduce(ExchangeRateSettings.crypto_to_update(), %{}, fn crypto, acc ->
      Map.put(acc, crypto, fiat)
    end)
  end

  @impl true
  def request_type, do: :multi

  @impl true
  def rates(opts) do
    from = Keyword.fetch!(opts, :from)
    to = Keyword.fetch!(opts, :to)

    Enum.reduce(from, %{}, fn crypto_id, acc ->
      Map.put(
        acc,
        crypto_id,
        Enum.reduce(to, %{}, fn fiat_id, acc ->
          Map.put(acc, fiat_id, UtilFactory.rand_decimal())
        end)
      )
    end)
  end
end
