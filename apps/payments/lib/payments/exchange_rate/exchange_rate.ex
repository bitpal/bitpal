defmodule Payments.ExchangeRate do
  alias Payments.ExchangeRate.Kraken
  alias Payments.ExchangeRate.Cache

  def compute(pair = {:bch, :usd}) do
    case Cache.fetch(pair) do
      {:ok, res} -> res
      :error -> get_rate(pair)
    end
  end

  defp get_rate(pair) do
    rate = Kraken.compute(pair)
    :ok = Cache.put(pair, rate)
    rate
  end
end
