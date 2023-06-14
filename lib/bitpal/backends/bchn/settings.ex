defmodule BitPal.Backend.BCHN.Settings do
  alias BitPal.Files

  def net, do: fetch_config!(:net)
  def daemon_ip, do: fetch_config!(:daemon_ip)
  def daemon_port, do: fetch_config!(:daemon_port)
  def username, do: fetch_config!(:username)
  def password, do: fetch_config!(:password)

  def daemon_uri do
    "http://#{username()}:#{password()}@#{daemon_address()}"
  end

  def daemon_address do
    "#{daemon_ip()}:#{daemon_port()}"
  end

  def acceptable_unlock_time_blocks do
    # We expect one block every 2 minutes
    Kernel.trunc(acceptable_unlock_time_minutes() / 2.0)
  end

  def acceptable_unlock_time_minutes do
    24 * 60
  end

  def wallet_file do
    Files.wallet_file(:bchn, net())
  end

  # FIXME make more general
  defp fetch_config!(key) when is_atom(key) do
    config()[key] || raise "Missing BCHN config for key `#{key}`"
  end

  defp config do
    Application.fetch_env!(:bitpal, BitPal.Backend.BCHN)
  end
end
