import Config

config :money, :custom_currencies,
  BTC: %{name: "Bitcoin", exponent: 8},
  BCH: %{name: "Bitcoin Cash", exponent: 8},
  XMR: %{name: "Monero", exponent: 12},
  DGC: %{name: "Dogecoin", exponent: 8}

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
