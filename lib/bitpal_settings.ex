defmodule BitPalSettings do
  alias BitPal.BackendManager

  # Tests

  # FIXME do the same with tcp and rpc clients?
  @spec http_client :: module
  def http_client do
    Application.get_env(:bitpal, :http_client, BitPal.HTTPClient)
  end

  # Config updates

  @spec config_change(keyword, keyword, keyword) :: :ok
  def config_change(changed, new, removed) do
    BackendManager.config_change(changed, new, removed)
  end
end
