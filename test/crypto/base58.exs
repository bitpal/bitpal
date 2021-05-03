defmodule Base58Test do
  use ExUnit.Case, async: true
  alias BitPal.Crypto.Base58

  test "base58 encode" do
    # These examples are from the spec: https://tools.ietf.org/id/draft-msporny-base58-01.html

    assert Base58.encode("Hello World!") == "2NEpo7TZRRrLZSi2U"

    assert Base58.encode("The quick brown fox jumps over the lazy dog.") ==
             "USm3fpXnKG5EUBx2ndxBDMPVciP5hGey2Jh4NDv6gmeo1LkMeiKrLJUUBk6Z"

    # Note: This test case seems to be wrong in the above document. I have run it through the Base58
    # implementation in the github.com/bitcoin/bitcoin repo, and that produces the same output as we
    # do (as well as various other encoders/decoders available). In any case, addresses are usually
    # prefixed with some known non-zero bytes, meaning that this potential issue will not affect our
    # use-cases.
    # assert Base58.encode(<<0x00, 0x00, 0x28, 0x7F, 0xB4, 0xCD>>) == "111233QC4"

    # This is the "correct" one, one less "1" in the string.
    assert Base58.encode(<<0x00, 0x00, 0x28, 0x7F, 0xB4, 0xCD>>) == "11233QC4"

    # When following the xpub format, we shall get well-known characters at the start of the string:
    assert String.slice(Base58.encode(<<0x04, 0x88, 0xB2, 0x1E, 0::78*8>>), 0, 4) == "xpub"
    assert String.slice(Base58.encode(<<0x04, 0x88, 0xAD, 0xE4, 0::78*8>>), 0, 4) == "xprv"
  end

  test "base58 decode" do
    # These examples are from the spec: https://tools.ietf.org/id/draft-msporny-base58-01.html

    assert Base58.decode("2NEpo7TZRRrLZSi2U") == "Hello World!"

    assert Base58.decode("USm3fpXnKG5EUBx2ndxBDMPVciP5hGey2Jh4NDv6gmeo1LkMeiKrLJUUBk6Z") ==
             "The quick brown fox jumps over the lazy dog."

    # Note: This test case seems to be wrong in the above document. I have run it through the Base58
    # implementation in the github.com/bitcoin/bitcoin repo, and that produces the same output as we
    # do (as well as various other encoders/decoders available). In any case, addresses are usually
    # prefixed with some known non-zero bytes, meaning that this potential issue will not affect our
    # use-cases.
    # assert Base58.decode("111233QC4") == <<0x00, 0x00, 0x28, 0x7F, 0xB4, 0xCD>>

    # This is the "correct" one, one less "1" in the string.
    assert Base58.decode("11233QC4") == <<0x00, 0x00, 0x28, 0x7F, 0xB4, 0xCD>>
  end
end
