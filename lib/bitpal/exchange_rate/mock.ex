defmodule BitPal.ExchangeRateMock do
  @behaviour BitPal.ExchangeRate.Backend

  alias BitPal.ExchangeRateSupervisor.Result

  @impl true
  def name, do: "mock"

  @impl true
  def supported_pairs, do: [{:bch, :usd}, {:bch, :eur}]

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
