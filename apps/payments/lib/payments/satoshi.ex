defmodule Payments.Satoshi do
  @satoshi 100_000_000

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
end
