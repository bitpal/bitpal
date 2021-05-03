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

  test "decode address 2" do
    address = "bitcoincash:qrwjyrzae2av8wxvt79e2ukwl9q58m3u6cwn8k2dpa"

    wanted =
      {:p2kh,
       <<221, 34, 12, 93, 202, 186, 195, 184, 204, 95, 139, 149, 114, 206, 249, 65, 67, 238, 60,
         214>>}

    assert Cashaddress.decode_cash_url(address) == wanted
  end

  test "failing checksum" do
    address = "bitcoincash:qrx5lc6m2wjkqncfzefn49wr3cfvx7l36ydexxxxxx"

    assert_raise RuntimeError, fn ->
      Cashaddress.decode_cash_url(address)
    end
  end
end
