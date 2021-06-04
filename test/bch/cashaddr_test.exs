defmodule CashaddressTest do
  use ExUnit.Case, async: true
  alias BitPal.BCH.Cashaddress

  test "decode address" do
    address = "bitcoincash:qrx5lc6m2wjkqncfzefn49wr3cfvx7l36yderrc7x3"

    wanted =
      {:p2pkh,
       <<205, 79, 227, 91, 83, 165, 96, 79, 9, 22, 83, 58, 149, 195, 142, 18, 195, 123, 241, 209>>}

    assert Cashaddress.decode_cash_url(address) == wanted
  end

  test "decode address 2" do
    address = "bitcoincash:qrwjyrzae2av8wxvt79e2ukwl9q58m3u6cwn8k2dpa"

    wanted =
      {:p2pkh,
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

  test "roundtrip" do
    address = "bitcoincash:qrwjyrzae2av8wxvt79e2ukwl9q58m3u6cwn8k2dpa"

    assert Cashaddress.encode_cash_url(Cashaddress.decode_cash_url(address)) == address
  end

  test "xpub generation" do
    start_supervised!(BitPal.RuntimeStorage)

    xpub =
      "xpub6C23JpFE6ABbBudoQfwMU239R5Bm6QGoigtLq1BD3cz3cC6DUTg89H3A7kf95GDzfcTis1K1m7ypGuUPmXCaCvoxDKbeNv6wRBEGEnt1NV7"

    assert Cashaddress.derive_address(xpub, 0) ==
             "bitcoincash:qzhw8q9n8dqetkzx5mg3xh43uqhumx5rl549dlrs72"

    assert Cashaddress.derive_address(xpub, 1) ==
             "bitcoincash:qp5a3tww8w4lsff8txus74xl7tewg48zg5xcmzmc3a"

    assert Cashaddress.derive_address(xpub, 2) ==
             "bitcoincash:qzyjg9scvhpz6q8xckpzgfa40d44ajqkcql4xk77nk"

    assert Cashaddress.derive_address(xpub, 3) ==
             "bitcoincash:qpwpwv6pdlpg34qh0jmtvq70p5c7s4x54utdhchqsq"

    assert Cashaddress.derive_address(xpub, 4) ==
             "bitcoincash:qp5frsrzj7d6ufvvf2r4tfwekd9dr2ewdg6wvcl8uz"

    assert Cashaddress.derive_address(xpub, 5) ==
             "bitcoincash:qz9r4k26kr0f0jna27g6sn4veucrh3fvtqqe2qx6rq"

    assert Cashaddress.derive_address(xpub, 6) ==
             "bitcoincash:qr7v26r7dk0c9ru32nvm3lc4dqacskkhqq9dwdae8a"

    assert Cashaddress.derive_address(xpub, 7) ==
             "bitcoincash:qql66ejz4svvdkf62lkwuyw4sx4q7509fqlzp6vfq8"

    assert Cashaddress.derive_address(xpub, 8) ==
             "bitcoincash:qrr0zh72upt7vk0kfu6p2twr2m6872mpj5nneyx5a3"

    assert Cashaddress.derive_address(xpub, 9) ==
             "bitcoincash:qr5rrfvvwx9md3jnsuje8vdhzvpxtqrf3qyytcgxf2"

    assert Cashaddress.derive_address(xpub, 10) ==
             "bitcoincash:qpk545j782qmmsavfzku4x6tzf50pg4wrckt8zg5zy"

    assert Cashaddress.derive_address(xpub, 11) ==
             "bitcoincash:qzytvqurteurp2rq4rx85unhg9c2ktuqac7349xpph"

    assert Cashaddress.derive_address(xpub, 12) ==
             "bitcoincash:qzesz6u8xkvlwrl5csqs48geu3yywmxhmcwrx7jxcw"

    assert Cashaddress.derive_address(xpub, 13) ==
             "bitcoincash:qpr2s73xaemy5zew0xjulurm89a8x2zckuwds6kck2"

    assert Cashaddress.derive_address(xpub, 14) ==
             "bitcoincash:qqm8vl2e8009tslgvztujlrpdnhylykl0sgwss4tak"

    assert Cashaddress.derive_address(xpub, 15) ==
             "bitcoincash:qr0827pg83rdn2zn52yk0hz0j6fq0jafe5djrez3kf"

    assert Cashaddress.derive_address(xpub, 16) ==
             "bitcoincash:qpvjknpw0j3ke3p2s2s6wd2zrv68xp5zjs7pks6hdx"

    assert Cashaddress.derive_address(xpub, 17) ==
             "bitcoincash:qzt7pxqhd44uzp50y5w3wdj03uwcqzxrpqqldwa4xs"

    assert Cashaddress.derive_address(xpub, 18) ==
             "bitcoincash:qq0yv8w5j2geuaph9cmcfcdpqqaawz4fuv808ctpsg"

    assert Cashaddress.derive_address(xpub, 19) ==
             "bitcoincash:qqzz4tu6gslx2md6vzagh3qq47etv028ru7f0z30al"
  end
end
