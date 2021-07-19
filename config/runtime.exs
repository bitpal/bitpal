import Config

config :bitpal,
  xpub:
    "xpub6C23JpFE6ABbBudoQfwMU239R5Bm6QGoigtLq1BD3cz3cC6DUTg89H3A7kf95GDzfcTis1K1m7ypGuUPmXCaCvoxDKbeNv6wRBEGEnt1NV7",
  required_confirmations: 0,
  double_spend_timeout: 2_000

case Config.config_env() do
  :dev ->
    config :bitpal, backends: [{BitPal.BackendMock, auto: true, time_between_blocks: 60_000}]

    config :bitpal, BitPal.ExchangeRate,
      backends: [BitPal.ExchangeRateMock],
      timeout: 2_000

  :test ->
    config :bitpal,
      backends: [],
      http_client: BitPal.TestHTTPClient

    config :bitpal, BitPal.ExchangeRate,
      backends: [BitPal.ExchangeRate.Kraken],
      timeout: 2_000

  :prod ->
    config :bitpal,
      backends: [BitPal.Backend.Flowee],
      http_client: BitPal.TestHTTPClient

    config :bitpal, BitPal.ExchangeRate,
      backends: [BitPal.ExchangeRate.Kraken],
      timeout: 2_000

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
end
