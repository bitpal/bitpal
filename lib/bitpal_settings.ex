defmodule BitPalSettings do
  alias BitPal.BackendManager

  # Transaction processing

  @spec currency_backends :: [Supervisor.child_spec() | {module, term} | module]
  def currency_backends do
    Application.fetch_env!(:bitpal, :backends)
  end

  # Exchange rates

  @spec exchange_rate_backends :: [module]
  def exchange_rate_backends do
    fetch_env!(:bitpal, BitPal.ExchangeRate, :backends)
  end

  @spec exchange_rate_timeout :: non_neg_integer
  def exchange_rate_timeout do
    fetch_env!(:bitpal, BitPal.ExchangeRate, :request_timeout)
  end

  @spec exchange_rate_refresh_rate :: non_neg_integer
  def exchange_rate_refresh_rate do
    fetch_env!(:bitpal, BitPal.ExchangeRate, :refresh_rate)
  end

  @spec exchange_rate_ttl :: non_neg_integer
  def exchange_rate_ttl do
    fetch_env!(:bitpal, BitPal.ExchangeRate, :cache_ttl)
  end

  @spec exchange_rate_ttl_check_interval :: non_neg_integer
  def exchange_rate_ttl_check_interval do
    fetch_env!(:bitpal, BitPal.ExchangeRate, :cache_ttl_check_interval)
  end

  # Tests

  @spec http_client :: module
  def http_client do
    Application.get_env(:bitpal, :http_client, BitPal.HTTPClient)
  end

  # Config updates

  @spec config_change(keyword, keyword, keyword) :: :ok
  def config_change(changed, new, removed) do
    BackendManager.config_change(changed, new, removed)
  end

  def fetch_env!(app, key, subkey) do
    Keyword.fetch!(Application.fetch_env!(app, key), subkey)
  end
end
