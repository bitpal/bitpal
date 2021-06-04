import Config

config :bitpal,
  address: "bitcoincash:qqpkcce4lzdc8guam5jfys9prfyhr90seqzakyv4tu",
  xpub:
    "xpub6C23JpFE6ABbBudoQfwMU239R5Bm6QGoigtLq1BD3cz3cC6DUTg89H3A7kf95GDzfcTis1K1m7ypGuUPmXCaCvoxDKbeNv6wRBEGEnt1NV7",
  required_confirmations: 0

case Config.config_env() do
  :dev ->
    # Mocking during development. If you want to test live replace it with a backend of your choice.
    config :bitpal,
      backends: [{BitPal.BackendMock, auto: true}]

    config :bitpal, BitPal.ExchangeRate, backends: [BitPal.ExchangeRate.Mock]

    config :bitpal, BitPal.Repo,
      username: "postgres",
      password: "postgres",
      database: "bitpal_dev",
      hostname: "localhost",
      show_sensitive_data_on_connection_error: true,
      pool_size: 10

  :test ->
    config :bitpal,
      backends: [],
      http_client: BitPal.TestHTTPClient

    config :bitpal, BitPal.ExchangeRate, backends: [BitPal.ExchangeRate.Kraken]

    # The MIX_TEST_PARTITION environment variable can be used
    # to provide built-in test partitioning in CI environment.
    # Run `mix help test` for more information.
    config :bitpal, BitPal.Repo,
      username: "postgres",
      password: "postgres",
      database: "bitpal_test#{System.get_env("MIX_TEST_PARTITION")}",
      hostname: "localhost",
      pool: Ecto.Adapters.SQL.Sandbox

  _ ->
    :ok
end
