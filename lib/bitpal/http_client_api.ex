defmodule BitPal.HTTPClientAPI do
  @callback request_body(String.t()) :: {:ok, String.t()}
end
