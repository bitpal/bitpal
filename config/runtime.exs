import Config

# Timeouts are in ms

# These should be overridable via BitPalConfig later
config :bitpal,
  xpub:
    "xpub6C23JpFE6ABbBudoQfwMU239R5Bm6QGoigtLq1BD3cz3cC6DUTg89H3A7kf95GDzfcTis1K1m7ypGuUPmXCaCvoxDKbeNv6wRBEGEnt1NV7",
  required_confirmations: 0,
  double_spend_timeout: 2_000

config :bitpal, BitPal.ExchangeRate,
  # How long should we wait for external services to respond?
  # 5s
  request_timeout: 5_000,
  # Set to :infinity to turn off auto refresh
  # 10 minutes = 1_000 * 60 * 10
  refresh_rate: 1_000 * 60 * 10,
  # How long should exchange rates be valid? 
  # 15 minutes = 1_000 * 60 * 15
  cache_ttl: 1_000 * 60 * 15,
  # Check for expiry every 1 min
  cache_ttl_check_interval: 1_000 * 60

case Config.config_env() do
  :dev ->
    config :bitpal,
      backends: [{BitPal.BackendMock, auto: true, time_between_blocks: 60_000}]

    config :bitpal, BitPal.ExchangeRate, backends: [BitPal.ExchangeRateMock]

  :test ->
    config :bitpal,
      backends: [],
      http_client: BitPal.TestHTTPClient

    config :bitpal, BitPal.ExchangeRate, backends: [BitPal.ExchangeRate.Kraken]

  :prod ->
    xpub =
      System.get_env("XPUB") ||
        raise """
        environment variable XPUB is missing.
        You need to generate one from a wallet.
        """

    config :bitpal,
      backends: [BitPal.Backend.Flowee],
      xpub: xpub,
      required_confirmations: System.get_env("REQUIRED_CONFIRMATIONS") || 0,
      double_spend_timeout: System.get_env("DOUBLE_SPEND_TIMEOUT") || 2_000

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
end
