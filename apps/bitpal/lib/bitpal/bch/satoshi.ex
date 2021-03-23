defmodule BitPal.BCH.Satoshi do
  @satoshi 100_000_000

  defstruct([:amount])

  # Convert from satoshi integer to BCH float
  def satoshi_to_bch(satoshi) do
    Decimal.div(Decimal.new(satoshi), Decimal.new(@satoshi))
    |> Decimal.to_float()
  end

  # Convert from BCH float to satoshi integer
  def bch_to_satoshi(bch) do
    Decimal.mult(Decimal.from_float(bch), Decimal.new(@satoshi))
    |> Decimal.round(0, :down)
    |> Decimal.to_integer()
  end

  def from_decimal(data) do
    amount =
      data
      |> Decimal.mult(Decimal.new(@satoshi))
      |> Decimal.round(0, :down)
      |> Decimal.to_integer()

    %BitPal.BCH.Satoshi{amount: amount}
  end

  @spec to_decimal(BitPal.BCH.Satoshi) :: Decimal
  def to_decimal(%BitPal.BCH.Satoshi{amount: amount}) do
    amount
    |> Decimal.new()
    |> Decimal.div(Decimal.new(@satoshi))
  end
end

defimpl BitPal.BaseUnit, for: BitPal.BCH.Satoshi do
  def to_decimal(data) do
    BitPal.BCH.Satoshi.to_decimal(data)
  end
end
