import Config

case Config.config_env() do
  :dev ->
    # Mocking during development. If you want to test live comment it out.
    config :bitpal,
      backends: [{BitPal.BackendMock, auto: true}]

    config :bitpal, BitPal.ExchangeRate, backends: [BitPal.ExchangeRate.Mock]

  :test ->
    config :bitpal,
      backends: [],
      http_client: BitPal.TestHTTPClient

    config :bitpal, BitPal.ExchangeRate, backends: [BitPal.ExchangeRate.Kraken]

  _ ->
    :ok
end
