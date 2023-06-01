defmodule BitPal.RPCClientAPI do
  @callback call(String.t(), JSONRPC2.method(), JSONRPC2.params()) :: {:ok, term} | {:error, term}
end
