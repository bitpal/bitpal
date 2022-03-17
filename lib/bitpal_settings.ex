defmodule BitPalSettings do
  alias BitPal.BackendManager

  # Transaction processing

  @spec currency_backends :: [Supervisor.child_spec() | {module, term} | module]
  def currency_backends do
    Application.fetch_env!(:bitpal, :backends)
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
