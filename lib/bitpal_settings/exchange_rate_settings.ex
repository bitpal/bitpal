defmodule BitPalSettings.ExchangeRateSettings do
  alias BitPal.BackendManager

  @fiat_to_update Application.compile_env!(:bitpal, [BitPal.ExchangeRate, :fiat_to_update])
  @retry_timeout Application.compile_env!(:bitpal, [BitPal.ExchangeRate, :retry_timeout])
  @rates_refresh_rate Application.compile_env!(:bitpal, [BitPal.ExchangeRate, :rates_refresh_rate])
  @rates_ttl Application.compile_env!(:bitpal, [BitPal.ExchangeRate, :rates_ttl])
  @supported_refresh_rate Application.compile_env!(
                            :bitpal,
                            [BitPal.ExchangeRate, :supported_refresh_rate]
                          )
  @extra_crypto_to_update Application.compile_env(
                            :bitpal,
                            [BitPal.ExchangeRate, :extra_crypto_to_update],
                            []
                          )

  @spec fiat_to_update :: [atom]
  def fiat_to_update, do: @fiat_to_update

  @spec crypto_to_update :: [atom]
  def crypto_to_update do
    Enum.uniq(@extra_crypto_to_update ++ BackendManager.currency_list())
  end

  @spec retry_timeout :: non_neg_integer
  def retry_timeout, do: @retry_timeout

  @spec rates_refresh_rate :: non_neg_integer
  def rates_refresh_rate, do: @rates_refresh_rate

  @spec supported_refresh_rate :: non_neg_integer
  def supported_refresh_rate, do: @supported_refresh_rate

  @spec rates_ttl :: non_neg_integer
  def rates_ttl, do: @rates_ttl
end
