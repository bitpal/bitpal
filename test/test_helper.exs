Mox.defmock(FloweeMock, for: BitPal.TCPClientAPI)

# For some reason logger doesn't take regular config settings when started this way...
Logger.configure(level: :warn)

BitPal.Currencies.ensure_exists!([:BCH, :XMR, :DGC])

BitPal.ServerSetup.set_state(:completed)

ExUnit.start()
Faker.start()
Ecto.Adapters.SQL.Sandbox.mode(BitPal.Repo, :manual)
