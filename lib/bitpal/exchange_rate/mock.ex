defmodule BitPal.ExchangeRateMock do
  alias BitPal.ExchangeRate.Result

  @behaviour BitPal.ExchangeRate.Backend

  @impl true
  def name(), do: "mock"

  @impl true
  def supported_pairs(), do: [{:bch, :usd}, {:bch, :eur}]

  @impl true
  def compute(_pair, _opts) do
    {:ok,
     %Result{
       score: 10,
       backend: __MODULE__,
       rate: Decimal.from_float(1.337)
     }}
  end
end
