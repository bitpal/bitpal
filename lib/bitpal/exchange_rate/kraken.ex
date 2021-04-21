defmodule BitPal.ExchangeRate.Kraken do
  require Logger
  alias BitPal.ExchangeRate.Result

  @behaviour BitPal.ExchangeRate.Backend

  @base "https://api.kraken.com/0/public/Ticker?pair="

  @impl true
  def name(), do: "kraken"

  @impl true
  def supported_pairs(), do: [{:bch, :usd}, {:bch, :eur}]

  @impl true
  def compute(pair, _opts) do
    Logger.debug("Computing Kraken exchange rate #{inspect(pair)}")

    {:ok,
     %Result{
       score: 100,
       backend: __MODULE__,
       rate: get_rate(pair)
     }}
  end

  defp get_rate(pair) do
    pair = pair2str(pair)

    http = Application.get_env(:bitpal, :http_client, BitPal.HTTPClient)

    {:ok, body} = http.request_body(url(pair))

    body
    |> decode
    |> transform_rate(pair)
  end

  defp pair2str({from, to}) do
    Atom.to_string(from) <> Atom.to_string(to)
  end

  defp url(pair) do
    @base <> String.downcase(pair)
  end

  defp decode(body) do
    Poison.decode!(body)
  end

  defp transform_rate(%{"result" => res}, pair) do
    {f, ""} =
      res[String.upcase(pair)]["c"]
      |> List.first()
      |> Float.parse()

    Decimal.from_float(f)
  end
end
