import Config

case Config.config_env() do
  :prod ->
    config :bitpal,
      backends: [BitPal.Backend.Flowee]

    config :bitpal, BitPal.ExchangeRate, backends: [BitPal.ExchangeRate.Kraken]

    secret_key_base =
      System.get_env("SECRET_KEY_BASE") ||
        raise """
        environment variable SECRET_KEY_BASE is missing.
        You can generate one by calling: mix phx.gen.secret
        """

    config :bitpal, secret_key_base: secret_key_base
    config :bitpal, BitPalApi.Endpoint, secret_key_base: secret_key_base
    config :bitpal, BitPalWeb.Endpoint, secret_key_base: secret_key_base

    database_url =
      System.get_env("DATABASE_URL") ||
        raise """
        environment variable DATABASE_URL is missing.
        For example: ecto://USER:PASS@HOST/DATABASE
        """

    config :bitpal, BitPal.Repo,
      # ssl: true,
      url: database_url,
      pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

  :dev ->
    config :bitpal,
      backends: [{BitPal.BackendMock, auto: true, time_between_blocks: 60_000}]

    config :bitpal, BitPal.ExchangeRate, backends: [BitPal.ExchangeRateMock]

  :test ->
    config :bitpal,
      backends: [],
      http_client: BitPal.TestHTTPClient

    config :bitpal, BitPal.ExchangeRate, backends: [BitPal.ExchangeRate.Kraken]
end
