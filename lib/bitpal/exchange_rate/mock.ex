defmodule BitPal.ExchangeRateMock do
  @behaviour BitPal.ExchangeRate.Backend

  alias BitPal.ExchangeRate
  alias BitPal.ExchangeRateSupervisor.Result

  @impl true
  def name, do: "mock"

  @impl true
  def supported_pairs, do: [{:BCH, :USD}, {:BCH, :EUR}]

  @impl true
  def compute(pair, _opts) do
    {:ok,
     %Result{
       score: 10,
       backend: __MODULE__,
       rate: ExchangeRate.new!(Decimal.from_float(1.337), pair)
     }}
  end
end
