defmodule BitPal.HTTPClient do
  @spec request_body(String.t()) :: {:ok, String.t()}
  def request_body(url) do
    {:ok, %HTTPoison.Response{status_code: 200, body: body}} = HTTPoison.get(url)
    {:ok, body}
  end
end
