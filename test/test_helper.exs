Mox.defmock(BitPal.FloweeMock, for: BitPal.TCPClientAPI)
Mox.defmock(BitPal.ExchangeRate.MockSource, for: BitPal.ExchangeRate.Source)
Mox.defmock(BitPal.ExchangeRate.MockSource2, for: BitPal.ExchangeRate.Source)

Mox.defmock(BitPal.MockHTTPClient, for: BitPal.HTTPClientAPI)
Application.put_env(:bitpal, :http_client, BitPal.MockHTTPClient)

BitPal.Currencies.ensure_exists!([:BCH, :XMR, :DGC])

BitPal.ServerSetup.set_state(:completed)

ExUnit.start()
Faker.start()
Ecto.Adapters.SQL.Sandbox.mode(BitPal.Repo, :manual)
