defmodule BitPal.ExchangeRate.Sources.Empty do
  @behaviour BitPal.ExchangeRate.Source

  alias BitPalSettings.ExchangeRateSettings

  @impl true
  def rate_limit_settings do
    %{
      timeframe: 1_000,
      timeframe_max_requests: 10,
      timeframe_unit: :milliseconds
    }
  end

  @impl true
  def name, do: "Empty"

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
  def rates(_opts), do: %{}
end
