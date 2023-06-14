import Config

# Settings that should be controllable from the web UI

config :bitpal, BitPal.Backend.BCHN,
  net: :mainnet,
  daemon_ip: "localhost",
  daemon_port: 8332,
  username: "username",
  password: "password"

config :bitpal, BitPal.Backend.Monero,
  # 18081 for mainnet, 28081 for testnet and 38081 for stagenet
  # Remember that a mainneet wallet setup isn't valid on stagenet
  daemon_ip: "localhost",
  net: :stagenet,
  daemon_port: 38081

config :bitpal, BitPal.ExchangeRate,
  sources: [{BitPal.ExchangeRate.Sources.Random, prio: 10}],
  rates_refresh_rate: 1_000 * 60 * 1,
  supported_refresh_rate: 1_000 * 60 * 60 * 24,
  request_timeout: 5_000,
  retry_timeout: 5_000,
  rates_ttl: 1_000 * 60 * 60,
  fiat_to_update: [
    :EUR,
    :SEK,
    :USD
  ],
  extra_crypto_to_update: [:BTC, :BCH, :XMR, :DGC, :LTC]

# Fixed settings

config :main_proxy,
  http: [:inet6, port: 4000]

config :bitpal, BitPal.BackendManager,
  restart_timeout: 3_000,
  backends: [
    BitPal.Backend.BCHN
    # BitPal.Backend.Monero
    # This uses a completely unique currency that's only used for testing.
    # {BitPal.BackendMock, auto: true, time_between_blocks: 2_000, sync_time: 10_000}
    # These specifies currencies directly.
    # {BitPal.BackendMock, auto: true, time_between_blocks: 10 * 60 * 1_000, currency_id: :BCH},
    # {BitPal.BackendMock, auto: true, time_between_blocks: 3 * 60 * 1_000, currency_id: :XMR}
  ]

config :bitpal, BitPal.Repo,
  username: "postgres",
  password: "postgres",
  database: "bitpal_dev",
  hostname: "localhost",
  show_sensitive_data_on_connection_error: true,
  pool_size: 20,
  queue_target: 5000

config :bitpal, BitPalApi.Endpoint,
  debug_errors: false,
  code_reloader: true,
  check_origin: false

config :bitpal, BitPalWeb.Endpoint,
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
config :swoosh, serve_mailbox: true, preview_port: 4012

config :bitpal, BitPalFactory, init: true

config :logger, level: :info
