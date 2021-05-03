defmodule CashaddressTest do
  use ExUnit.Case, async: true
  alias BitPal.Crypto.Base32

  test "base32 5-bit encoding" do
    input = <<0x75, 0x1C>>
    # 0111 0101 0001 1100
    # => 01110 10100 01110 000
    assert Base32.to_5bit(input) == <<0x0E, 0x14, 0x0E, 0x00>>
    assert Base32.from_5bit(Base32.to_5bit(input)) == input
  end

  test "base32 roundtrip" do
    data = "this is some data for testing"

    assert Base32.decode(Base32.encode(data)) == data
  end
end
