defmodule BitPal.NumberHelpers do
  require Decimal

  @spec cast_decimal(any) :: {:ok, Decimal.t()} | :error
  def cast_decimal(x) when is_float(x) do
    {:ok, Decimal.from_float(x) |> Decimal.normalize()}
  end

  def cast_decimal(x) when is_number(x) or is_bitstring(x) do
    {:ok, Decimal.new(x)}
  end

  def cast_decimal(x) do
    if Decimal.is_decimal(x) do
      {:ok, x}
    else
      :error
    end
  end
end
