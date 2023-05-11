use BitPalFactory
alias BitPal.Currencies
alias BitPal.Repo
alias BitPal.ServerSetup
alias BitPalSchemas.ExchangeRate

Mox.defmock(BitPal.FloweeMock, for: BitPal.TCPClientAPI)
Mox.defmock(BitPal.MoneroMock, for: BitPal.RPCClientAPI)
Mox.defmock(BitPal.ExchangeRate.MockSource, for: BitPal.ExchangeRate.Source)
Mox.defmock(BitPal.ExchangeRate.MockSource2, for: BitPal.ExchangeRate.Source)

Mox.defmock(BitPal.MockHTTPClient, for: BitPal.HTTPClientAPI)
Application.put_env(:bitpal, :http_client, BitPal.MockHTTPClient)

crypto = [:BCH, :XMR, :DGC]
Currencies.ensure_exists!(crypto)

now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

seeded_rates =
  for crypto_id <- crypto do
    for fiat_id <- [:USD, :EUR, :SEK] do
      %{
        base: crypto_id,
        quote: fiat_id,
        rate: random_rate(),
        source: :SEED,
        prio: 1,
        updated_at: now
      }
    end
  end
  |> List.flatten()

Repo.insert_all(ExchangeRate, seeded_rates,
  on_conflict: :replace_all,
  conflict_target: [:base, :quote, :source]
)

ServerSetup.set_state(:completed)

ExUnit.start()
Faker.start()
Ecto.Adapters.SQL.Sandbox.mode(BitPal.Repo, :manual)
