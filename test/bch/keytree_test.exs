defmodule KeyTreeTest do
  use ExUnit.Case, async: true
  alias BitPal.BCH.KeyTree

  test "encode public" do
    key =
      "xpub661MyMwAqRbcFtXgS5sYJABqqG9YLmC4Q1Rdap9gSE8NqtwybGhePY2gZ29ESFjqJoCu1Rupje8YtGqsefD265TMg7usUDFdp6W1EGMcet8"

    assert key |> KeyTree.import_key() |> KeyTree.export_key() == key
  end

  test "encode private" do
    key =
      "xprv9s21ZrQH143K3QTDL4LXw2F7HEK3wJUD2nW2nRk4stbPy6cq3jPPqjiChkVvvNKmPGJxWUtg6LnF5kejMRNNU3TGtRBeJgk33yuGBxrMPHi"

    assert key |> KeyTree.import_key() |> KeyTree.export_key() == key
  end

  defp derive_export(key, path), do: KeyTree.derive(key, path) |> KeyTree.export_key()

  # This is Test vector 1 from https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki
  # Note: We don't do key generation from a seed (it does not seem hard, so we could do it, but we don't need it).
  test "test vector 1" do
    seed =
      <<0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E,
        0x0F>>

    mpriv = KeyTree.from_seed(seed)
    mpub = KeyTree.to_public(mpriv)

    assert KeyTree.export_key(mpriv) ==
             "xprv9s21ZrQH143K3QTDL4LXw2F7HEK3wJUD2nW2nRk4stbPy6cq3jPPqjiChkVvvNKmPGJxWUtg6LnF5kejMRNNU3TGtRBeJgk33yuGBxrMPHi"

    assert KeyTree.export_key(mpub) ==
             "xpub661MyMwAqRbcFtXgS5sYJABqqG9YLmC4Q1Rdap9gSE8NqtwybGhePY2gZ29ESFjqJoCu1Rupje8YtGqsefD265TMg7usUDFdp6W1EGMcet8"

    assert derive_export(mpriv, "m/0'") ==
             "xprv9uHRZZhk6KAJC1avXpDAp4MDc3sQKNxDiPvvkX8Br5ngLNv1TxvUxt4cV1rGL5hj6KCesnDYUhd7oWgT11eZG7XnxHrnYeSvkzY7d2bhkJ7"

    assert derive_export(mpriv, "M/0'") ==
             "xpub68Gmy5EdvgibQVfPdqkBBCHxA5htiqg55crXYuXoQRKfDBFA1WEjWgP6LHhwBZeNK1VTsfTFUHCdrfp1bgwQ9xv5ski8PX9rL2dZXvgGDnw"

    assert derive_export(mpriv, "m/0'/1") ==
             "xprv9wTYmMFdV23N2TdNG573QoEsfRrWKQgWeibmLntzniatZvR9BmLnvSxqu53Kw1UmYPxLgboyZQaXwTCg8MSY3H2EU4pWcQDnRnrVA1xe8fs"

    assert derive_export(mpriv, "M/0'/1") ==
             "xpub6ASuArnXKPbfEwhqN6e3mwBcDTgzisQN1wXN9BJcM47sSikHjJf3UFHKkNAWbWMiGj7Wf5uMash7SyYq527Hqck2AxYysAA7xmALppuCkwQ"

    assert derive_export(mpriv, "m/0'/1/2'") ==
             "xprv9z4pot5VBttmtdRTWfWQmoH1taj2axGVzFqSb8C9xaxKymcFzXBDptWmT7FwuEzG3ryjH4ktypQSAewRiNMjANTtpgP4mLTj34bhnZX7UiM"

    assert derive_export(mpriv, "M/0'/1/2'") ==
             "xpub6D4BDPcP2GT577Vvch3R8wDkScZWzQzMMUm3PWbmWvVJrZwQY4VUNgqFJPMM3No2dFDFGTsxxpG5uJh7n7epu4trkrX7x7DogT5Uv6fcLW5"

    assert derive_export(mpriv, "m/0'/1/2'/2") ==
             "xprvA2JDeKCSNNZky6uBCviVfJSKyQ1mDYahRjijr5idH2WwLsEd4Hsb2Tyh8RfQMuPh7f7RtyzTtdrbdqqsunu5Mm3wDvUAKRHSC34sJ7in334"

    assert derive_export(mpriv, "M/0'/1/2'/2") ==
             "xpub6FHa3pjLCk84BayeJxFW2SP4XRrFd1JYnxeLeU8EqN3vDfZmbqBqaGJAyiLjTAwm6ZLRQUMv1ZACTj37sR62cfN7fe5JnJ7dh8zL4fiyLHV"

    assert derive_export(mpriv, "m/0'/1/2'/2/1000000000") ==
             "xprvA41z7zogVVwxVSgdKUHDy1SKmdb533PjDz7J6N6mV6uS3ze1ai8FHa8kmHScGpWmj4WggLyQjgPie1rFSruoUihUZREPSL39UNdE3BBDu76"

    assert derive_export(mpriv, "M/0'/1/2'/2/1000000000") ==
             "xpub6H1LXWLaKsWFhvm6RVpEL9P4KfRZSW7abD2ttkWP3SSQvnyA8FSVqNTEcYFgJS2UaFcxupHiYkro49S8yGasTvXEYBVPamhGW6cFJodrTHy"
  end

  test "test vector 2" do
    seed =
      <<0xFF, 0xFC, 0xF9, 0xF6, 0xF3, 0xF0, 0xED, 0xEA, 0xE7, 0xE4, 0xE1, 0xDE, 0xDB, 0xD8, 0xD5,
        0xD2, 0xCF, 0xCC, 0xC9, 0xC6, 0xC3, 0xC0, 0xBD, 0xBA, 0xB7, 0xB4, 0xB1, 0xAE, 0xAB, 0xA8,
        0xA5, 0xA2, 0x9F, 0x9C, 0x99, 0x96, 0x93, 0x90, 0x8D, 0x8A, 0x87, 0x84, 0x81, 0x7E, 0x7B,
        0x78, 0x75, 0x72, 0x6F, 0x6C, 0x69, 0x66, 0x63, 0x60, 0x5D, 0x5A, 0x57, 0x54, 0x51, 0x4E,
        0x4B, 0x48, 0x45, 0x42>>

    mpriv = KeyTree.from_seed(seed)

    assert derive_export(mpriv, "m") ==
             "xprv9s21ZrQH143K31xYSDQpPDxsXRTUcvj2iNHm5NUtrGiGG5e2DtALGdso3pGz6ssrdK4PFmM8NSpSBHNqPqm55Qn3LqFtT2emdEXVYsCzC2U"

    assert derive_export(mpriv, "M") ==
             "xpub661MyMwAqRbcFW31YEwpkMuc5THy2PSt5bDMsktWQcFF8syAmRUapSCGu8ED9W6oDMSgv6Zz8idoc4a6mr8BDzTJY47LJhkJ8UB7WEGuduB"

    assert derive_export(mpriv, "m/0") ==
             "xprv9vHkqa6EV4sPZHYqZznhT2NPtPCjKuDKGY38FBWLvgaDx45zo9WQRUT3dKYnjwih2yJD9mkrocEZXo1ex8G81dwSM1fwqWpWkeS3v86pgKt"

    assert derive_export(mpriv, "M/0") ==
             "xpub69H7F5d8KSRgmmdJg2KhpAK8SR3DjMwAdkxj3ZuxV27CprR9LgpeyGmXUbC6wb7ERfvrnKZjXoUmmDznezpbZb7ap6r1D3tgFxHmwMkQTPH"

    assert derive_export(mpriv, "m/0/2147483647'") ==
             "xprv9wSp6B7kry3Vj9m1zSnLvN3xH8RdsPP1Mh7fAaR7aRLcQMKTR2vidYEeEg2mUCTAwCd6vnxVrcjfy2kRgVsFawNzmjuHc2YmYRmagcEPdU9"

    assert derive_export(mpriv, "M/0/2147483647'") ==
             "xpub6ASAVgeehLbnwdqV6UKMHVzgqAG8Gr6riv3Fxxpj8ksbH9ebxaEyBLZ85ySDhKiLDBrQSARLq1uNRts8RuJiHjaDMBU4Zn9h8LZNnBC5y4a"

    assert derive_export(mpriv, "m/0/2147483647'/1") ==
             "xprv9zFnWC6h2cLgpmSA46vutJzBcfJ8yaJGg8cX1e5StJh45BBciYTRXSd25UEPVuesF9yog62tGAQtHjXajPPdbRCHuWS6T8XA2ECKADdw4Ef"

    assert derive_export(mpriv, "M/0/2147483647'/1") ==
             "xpub6DF8uhdarytz3FWdA8TvFSvvAh8dP3283MY7p2V4SeE2wyWmG5mg5EwVvmdMVCQcoNJxGoWaU9DCWh89LojfZ537wTfunKau47EL2dhHKon"

    assert derive_export(mpriv, "m/0/2147483647'/1/2147483646'") ==
             "xprvA1RpRA33e1JQ7ifknakTFpgNXPmW2YvmhqLQYMmrj4xJXXWYpDPS3xz7iAxn8L39njGVyuoseXzU6rcxFLJ8HFsTjSyQbLYnMpCqE2VbFWc"

    assert derive_export(mpriv, "M/0/2147483647'/1/2147483646'") ==
             "xpub6ERApfZwUNrhLCkDtcHTcxd75RbzS1ed54G1LkBUHQVHQKqhMkhgbmJbZRkrgZw4koxb5JaHWkY4ALHY2grBGRjaDMzQLcgJvLJuZZvRcEL"

    assert derive_export(mpriv, "m/0/2147483647'/1/2147483646'/2") ==
             "xprvA2nrNbFZABcdryreWet9Ea4LvTJcGsqrMzxHx98MMrotbir7yrKCEXw7nadnHM8Dq38EGfSh6dqA9QWTyefMLEcBYJUuekgW4BYPJcr9E7j"

    assert derive_export(mpriv, "M/0/2147483647'/1/2147483646'/2") ==
             "xpub6FnCn6nSzZAw5Tw7cgR9bi15UV96gLZhjDstkXXxvCLsUXBGXPdSnLFbdpq8p9HmGsApME5hQTZ3emM2rnY5agb9rXpVGyy3bdW6EEgAtqt"
  end

  test "test vector 3" do
    seed =
      <<0x4B, 0x38, 0x15, 0x41, 0x58, 0x3B, 0xE4, 0x42, 0x33, 0x46, 0xC6, 0x43, 0x85, 0x0D, 0xA4,
        0xB3, 0x20, 0xE4, 0x6A, 0x87, 0xAE, 0x3D, 0x2A, 0x4E, 0x6D, 0xA1, 0x1E, 0xBA, 0x81, 0x9C,
        0xD4, 0xAC, 0xBA, 0x45, 0xD2, 0x39, 0x31, 0x9A, 0xC1, 0x4F, 0x86, 0x3B, 0x8D, 0x5A, 0xB5,
        0xA0, 0xD0, 0xC6, 0x4D, 0x2E, 0x8A, 0x1E, 0x7D, 0x14, 0x57, 0xDF, 0x2E, 0x5A, 0x3C, 0x51,
        0xC7, 0x32, 0x35, 0xBE>>

    mpriv = KeyTree.from_seed(seed)

    assert KeyTree.export_key(mpriv) ==
             "xprv9s21ZrQH143K25QhxbucbDDuQ4naNntJRi4KUfWT7xo4EKsHt2QJDu7KXp1A3u7Bi1j8ph3EGsZ9Xvz9dGuVrtHHs7pXeTzjuxBrCmmhgC6"

    assert derive_export(mpriv, "M") ==
             "xpub661MyMwAqRbcEZVB4dScxMAdx6d4nFc9nvyvH3v4gJL378CSRZiYmhRoP7mBy6gSPSCYk6SzXPTf3ND1cZAceL7SfJ1Z3GC8vBgp2epUt13"

    assert derive_export(mpriv, "m/0'") ==
             "xprv9uPDJpEQgRQfDcW7BkF7eTya6RPxXeJCqCJGHuCJ4GiRVLzkTXBAJMu2qaMWPrS7AANYqdq6vcBcBUdJCVVFceUvJFjaPdGZ2y9WACViL4L"

    assert derive_export(mpriv, "M/0'") ==
             "xpub68NZiKmJWnxxS6aaHmn81bvJeTESw724CRDs6HbuccFQN9Ku14VQrADWgqbhhTHBaohPX4CjNLf9fq9MYo6oDaPPLPxSb7gwQN3ih19Zm4Y"
  end

  test "matching public and private" do
    # Make sure that keys we derive from public and private paths are the same. This is vital for
    # our use. If our private key generation is off, then we will generate incorrect payment
    # addresses.

    # Note 'p' is our extension, it means "make it into a public key at this point".

    seed =
      <<0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E,
        0x0F>>

    mpriv = KeyTree.from_seed(seed)

    assert derive_export(mpriv, "0/3/8/p") == derive_export(mpriv, "p/0/3/8")
    assert derive_export(mpriv, "0/3/8/p") == derive_export(mpriv, "0/p/3/8")
    assert derive_export(mpriv, "0/3/8/p") == derive_export(mpriv, "0/3/p/8")
  end

  test "parse path" do
    assert KeyTree.parse_path("m/0/3/8'/8") == [0, 3, -9, 8]
    assert KeyTree.parse_path("M/0/3/8'/8") == [0, 3, -9, 8, :public]

    # Our extension.
    assert KeyTree.parse_path("0/3/p/8'") == [0, 3, :public, -9]
  end

  test "inspect path" do
    assert KeyTree.inspect_path([0, 3, -9, 8]) == "m/0/3/8'/8"
    assert KeyTree.inspect_path([0, 3, -9, 8, :public]) == "M/0/3/8'/8"
  end
end
