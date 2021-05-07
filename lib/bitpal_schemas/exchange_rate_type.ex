defmodule BitPalSchemas.Ecto.ExchangeRateType do
  use Ecto.Type
  import BitPal.NumberHelpers
  require Decimal

  @impl true
  def type, do: :exchange_rate

  @impl true
  def cast({amount, ticker}) when is_binary(ticker) do
    case cast_decimal(amount) do
      {:ok, dec} -> {:ok, {dec, ticker}}
      :error -> :error
    end
  end

  @impl true
  def cast(_) do
    :error
  end

  @impl true
  def load(data = {_amount, _ticker}) do
    {:ok, data}
  end

  @impl true
  def dump(data = {_amount, _ticker}), do: {:ok, data}
end
