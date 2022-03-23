defmodule BitPal.Backend.Monero.DaemonRPC do
  use GenServer
  alias JSONRPC2.Clients.HTTP

  # FIXME configurable
  @port 18081
  @url "http://localhost:#{@port}/json_rpc"

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_block_count() do
    call("get_block_count", %{})
  end

  def get_version() do
    call("get_version", %{})
  end

  def get_info() do
    call("get_info", %{})
  end

  def sync_info() do
    call("sync_info", %{})
  end

  # Server API

  @impl true
  def init(init_args) do
    {:ok, init_args}
  end

  defp call(method, params) do
    HTTP.call(@url, method, params)
  end
end
