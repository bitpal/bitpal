defmodule SatoshiTest do
  use ExUnit.Case, async: true
  alias BitPal.BCH.Satoshi

  test "convert decimal to satoshi" do
    dec = Decimal.from_float(1.2)
    satoshi = Satoshi.from_decimal(dec)
    assert satoshi.amount == 120_000_000
  end

  test "convert satoshi to decimal" do
    satoshi = %Satoshi{amount: 750_000}
    dec = Decimal.from_float(0.0075)
    assert BitPal.BaseUnit.to_decimal(satoshi) == dec
  end
end
