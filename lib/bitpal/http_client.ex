defmodule BitPal.HTTPClient do
  @behaviour BitPal.HTTPClientAPI

  @spec request_body(String.t()) :: {:ok, String.t()}
  @impl true
  def request_body(url) do
    {:ok, %HTTPoison.Response{status_code: 200, body: body}} = HTTPoison.get(url)
    {:ok, body}
  end
end
