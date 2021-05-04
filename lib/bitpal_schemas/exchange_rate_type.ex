defmodule BitPalSchemas.ExchangeRateType do
  use Ecto.Type
  require Decimal

  @impl true
  def type, do: :exchange_rate

  @impl true
  def cast({amount, ticker}) when is_binary(ticker) do
    cond do
      Decimal.is_decimal(amount) -> {:ok, {amount, ticker}}
      is_float(amount) -> {:ok, {Decimal.from_float(amount) |> Decimal.normalize(), ticker}}
      is_number(amount) || is_bitstring(amount) -> {:ok, {Decimal.new(amount), ticker}}
      true -> :error
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
