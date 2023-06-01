defmodule BitPal.RPCClient do
  @behaviour BitPal.RPCClientAPI

  alias JSONRPC2.Clients.HTTP

  @impl true
  def call(url, method, params) do
    HTTP.call(url, method, params)
  end
end
