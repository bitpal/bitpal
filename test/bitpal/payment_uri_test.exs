defmodule BitPal.PaymentUriTest do
  use ExUnit.Case, async: true
  use BitPalFactory
  import BitPal.PaymentUri

  describe "encode_address_with_meta" do
    test "encode BIP-21" do
      assert encode_address_with_meta("bitcoincash", "qrwjyrzae2av8wxvt79e2ukwl9q58m3u6cwn8k2dpa",
               label: "My sweet label",
               message: "Test message",
               amount: 1337
             ) ==
               "bitcoincash:qrwjyrzae2av8wxvt79e2ukwl9q58m3u6cwn8k2dpa?label=My%20sweet%20label&message=Test%20message&amount=1337"
    end

    test "skip prefix if included in address" do
      assert encode_address_with_meta(
               "bitcoincash",
               "bitcoincash:qrwjyrzae2av8wxvt79e2ukwl9q58m3u6cwn8k2dpa"
             ) ==
               "bitcoincash:qrwjyrzae2av8wxvt79e2ukwl9q58m3u6cwn8k2dpa"
    end

    test "one param" do
      assert encode_address_with_meta("pre", "addr", amount: 1) ==
               "pre:addr?amount=1"
    end

    test "two params" do
      assert encode_address_with_meta("pre", "addr", amount: 1, description: "descr") ==
               "pre:addr?amount=1&description=descr"
    end

    test "empty prefix" do
      assert encode_address_with_meta("", "addr") == "addr"
    end
  end
end
