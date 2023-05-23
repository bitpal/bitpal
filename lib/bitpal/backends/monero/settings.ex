defmodule BitPal.Backend.Monero.Settings do
  def net, do: fetch_config!(:net)
  def daemon_ip, do: fetch_config!(:daemon_ip)
  def daemon_port, do: fetch_config!(:daemon_port)
  def wallet_port, do: fetch_config!(:wallet_port)

  def daemon_uri do
    "http://localhost:#{daemon_port()}/json_rpc"
  end

  def wallet_uri do
    "http://localhost:#{wallet_port()}/json_rpc"
  end

  def acceptable_unlock_time_blocks do
    # We expect one block every 2 minutes
    Kernel.trunc(acceptable_unlock_time_minutes() / 2.0)
  end

  def acceptable_unlock_time_minutes do
    24 * 60
  end

  # FIXME make more general
  defp fetch_config!(key) when is_atom(key) do
    config()[key] || raise "Missing Monero config for key `#{key}`"
  end

  defp config do
    Application.fetch_env!(:bitpal, BitPal.Backend.Monero)
  end
end
