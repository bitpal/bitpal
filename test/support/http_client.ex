defmodule BitPal.TestHTTPClient do
  @kraken_bchusd File.read!("test/fixtures/kraken_bchusd.json")
  @kraken_bcheur File.read!("test/fixtures/kraken_bcheur.json")

  @spec request_body(String.t()) :: {:ok, String.t()}
  def request_body(url) do
    cond do
      String.contains?(url, "api.kraken.com/0/public/Ticker?pair=bchusd") -> {:ok, @kraken_bchusd}
      String.contains?(url, "api.kraken.com/0/public/Ticker?pair=bcheur") -> {:ok, @kraken_bcheur}
      true -> raise("response not implemented")
    end
  end
end
