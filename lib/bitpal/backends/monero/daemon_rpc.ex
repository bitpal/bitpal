defmodule BitPal.Backend.Monero.DaemonRPC do
  import BitPal.Backend.Monero.Settings
  require Logger

  # Client API

  def get_block_count(client) do
    call(client, "get_block_count")
  end

  def get_version(client) do
    call(client, "get_version")
  end

  def get_info(client) do
    call(client, "get_info")
  end

  def sync_info(client) do
    call(client, "sync_info")
  end

  defp call(client, method, params \\ %{}) do
    # Logger.notice("#{client} #{method}  #{inspect(params)}")
    client.call(daemon_uri(), method, params)
  end
end
