defmodule BitPal.ExchangeRate.Kraken do
  require Logger

  @base "https://api.kraken.com/0/public/Ticker?pair="

  def compute(pair = {:bch, :usd}) do
    Logger.info("Computing Kraken exchange rate #{inspect(pair)}")
    get_rate("bchusd")
  end

  defp get_rate(pair) do
    pair
    |> get_body
    |> decode
    |> rate(pair)
  end

  defp get_body(pair) do
    {:ok, %HTTPoison.Response{status_code: 200, body: body}} = HTTPoison.get(url(pair))
    body
  end

  defp url(pair) do
    @base <> String.downcase(pair)
  end

  defp decode(body) do
    Poison.decode!(body)
  end

  defp rate(%{"result" => res}, pair) do
    {f, ""} =
      res[String.upcase(pair)]["c"]
      |> List.first()
      |> Float.parse()

    f
  end
end
