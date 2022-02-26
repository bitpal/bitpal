Mox.defmock(FloweeMock, for: BitPal.TCPClientAPI)

BitPal.Currencies.ensure_exists!([:BCH, :XMR, :DGC])

BitPal.ServerSetup.set_state(:completed)

ExUnit.start()
Faker.start()
Ecto.Adapters.SQL.Sandbox.mode(BitPal.Repo, :manual)
