Mox.defmock(FloweeMock, for: BitPal.TCPClientAPI)

# For some reason logger doesn't take regular config settings when started this way...
Logger.configure(level: :warn)

BitPalFixtures.CurrencyFixtures.seed_supported_currencies()
BitPalFixtures.TestCurrencyCounter.start_link()

ExUnit.start()
Faker.start()
Ecto.Adapters.SQL.Sandbox.mode(BitPal.Repo, :manual)
