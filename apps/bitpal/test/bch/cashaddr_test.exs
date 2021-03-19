defmodule CashaddressTest do
  use ExUnit.Case, async: true
  alias BitPal.BCH.Cashaddress

  test "decode address" do
    address = "bitcoincash:qrx5lc6m2wjkqncfzefn49wr3cfvx7l36yderrc7x3"

    wanted =
      {:p2kh,
       <<205, 79, 227, 91, 83, 165, 96, 79, 9, 22, 83, 58, 149, 195, 142, 18, 195, 123, 241, 209>>}

    assert Cashaddress.decode_cash_url(address) == wanted
  end
end
