defmodule BitPalConfig do
  alias BitPal.BackendManager
  alias BitPal.InvoiceManager

  # Transaction processing

  @spec xpub :: String.t()
  def xpub do
    Application.fetch_env!(:bitpal, :xpub)
  end

  @spec required_confirmations :: non_neg_integer
  def required_confirmations do
    Application.fetch_env!(:bitpal, :required_confirmations)
  end

  @spec double_spend_timeout :: non_neg_integer
  def double_spend_timeout do
    Application.fetch_env!(:bitpal, :double_spend_timeout)
  end

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
  def config_change(changed, new, _removed) do
    update_config(changed)
    update_config(new)
  end

  defp update_config(opts) do
    if double_spend_timeout = Keyword.get(opts, :double_spend_timeout) do
      InvoiceManager.configure(double_spend_timeout: double_spend_timeout)
    end

    if backends = Keyword.get(opts, :backends) do
      BackendManager.configure(backends: backends)
    end

    # NOTE we want to handle this in a more general way later
    if conf = Keyword.get(opts, :required_confirmations) do
      Application.put_env(:bitpal, :required_confirmations, conf)
    end
  end

  defp fetch_env!(app, key, subkey) do
    Keyword.fetch!(Application.fetch_env!(app, key), subkey)
  end
end
