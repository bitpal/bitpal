defmodule BitPal.BCH.Satoshi do
  alias BitPal.BCH.Satoshi

  @satoshi 100_000_000

  @type t :: %__MODULE__{amount: non_neg_integer()}

  defstruct([:amount])

  @spec from_decimal(Decimal.t()) :: t()
  def from_decimal(data) do
    amount =
      data
      |> Decimal.mult(Decimal.new(@satoshi))
      |> Decimal.round(0, :down)
      |> Decimal.to_integer()

    %Satoshi{amount: amount}
  end

  @spec to_decimal(Satoshi.t()) :: Decimal.t()
  def to_decimal(%Satoshi{amount: amount}) do
    amount
    |> Decimal.new()
    |> Decimal.div(Decimal.new(@satoshi))
  end
end

defimpl BitPal.BaseUnit, for: BitPal.BCH.Satoshi do
  alias BitPal.BCH.Satoshi

  @spec to_decimal(Satoshi.t()) :: Decimal.t()
  def to_decimal(data) do
    Satoshi.to_decimal(data)
  end

  @spec to_smallest_unit(Satoshi.t()) :: non_neg_integer
  def to_smallest_unit(data) do
    data.amount
  end
end
