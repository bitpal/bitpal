import Config

config :bitpal,
  backends: [
    # BitPal.Backend.Flowee,
    # This uses a completely unique currency that's only used for testing.
    # {BitPal.BackendMock, auto: true, time_between_blocks: 2_000, sync_time: 10_000}
    # These specifies currencies directly.
    {BitPal.BackendMock, auto: true, time_between_blocks: 10 * 60 * 1_000, currency_id: :BCH},
    {BitPal.BackendMock, auto: true, time_between_blocks: 3 * 60 * 1_000, currency_id: :XMR}
  ]

config :bitpal, BitPal.ExchangeRate,
  # Where should we get our exchange rate information from?
  # If there are multiple sources with the same exchange rate pair,
  # the higher `prio` will decide which we use.
  sources: [
    # Real sources.
    # {BitPal.ExchangeRate.Sources.Kraken, prio: 100},
    # {BitPal.ExchangeRate.Sources.Coinbase, prio: 50},
    # {BitPal.ExchangeRate.Sources.Coingecko, prio: 0}
    # Gives random rates for all pairs.
    {BitPal.ExchangeRate.Sources.Random, prio: 10}
  ],
  # How often should we refresh the exchange rate?
  # 1 minute = 1_000 * 60 * 1
  rates_refresh_rate: 1_000 * 60 * 1,
  # How often should we refresh the supported exchange rate pairs?
  # 24 hours = 1_000 * 60 * 60 * 24
  supported_refresh_rate: 1_000 * 60 * 60 * 24,
  # How long should we wait for external services to respond?
  request_timeout: 5_000,
  # If the request failed, how long should we wait until we retry?
  retry_timeout: 5_000,
  # How long are exchange rates valid for?
  # Note that a lower refresh rate will update rates faster,
  # this is just a maximal value in case the external service is down.
  # 1 hour = 1_000 * 60 * 60
  rates_ttl: 1_000 * 60 * 60,
  # What fiat pairs should we keep updated?
  # The reason for this is that some sources can support a -lot- of
  # pairs, so we need to set what we should keep up to date.
  # All crypto that the backends support are of course updated.
  fiat_to_update: [
    :EUR,
    :SEK,
    :USD
  ],
  # What cryptocurrencies should we keep updated?
  # These will be in addition to the crypto supported by the backends.
  extra_crypto_to_update: [:BTC, :BCH, :XMR, :DGC, :LTC]

config :bitpal, BitPal.Repo,
  username: "postgres",
  password: "postgres",
  database: "bitpal_dev",
  hostname: "localhost",
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :bitpal, BitPalApi.Endpoint,
  http: [port: 4001],
  debug_errors: false,
  code_reloader: true,
  check_origin: false

config :bitpal, BitPalWeb.Endpoint,
  http: [port: 4002],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]},
    sass: {
      DartSass,
      :install_and_run,
      [:default, ~w(--embed-source-map --source-map-urls=absolute --watch)]
    }
  ],
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"lib/bitpal_web/(live|views)/.*(ex)$",
      ~r"lib/bitpal_web/templates/.*(eex)$",
      ~r"priv/server_docs/*.*(md)$"
    ]
  ]

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

# Run a preview email server during dev
config :bitpal, BitPal.Mailer, adapter: Swoosh.Adapters.Local

config :bitpal, BitPalFactory, init: true
config :bitpal, BitPal.BackendManager, reconnect_timeout: 3_000

config :swoosh, serve_mailbox: true, preview_port: 4011

config :logger, level: :info
