import Config

config :bitpal, BitPal.Backend.Monero,
  net: :stagenet,
  daemon_ip: "localhost",
  daemon_port: 38_081,
  wallet_port: 8332,
  # To avoid running the monero-wallet-rpc binary
  init_wallet: false

config :bitpal, BitPal.BackendManager,
  restart_timeout: 10,
  backends: []

config :bitpal, BitPal.ExchangeRate,
  sources: [
    # Empty is only used for manual tests that require manual rates for a source.
    {BitPal.ExchangeRate.Sources.Empty, prio: 1, id: :SEED, name: "Test seed"},
    {BitPal.ExchangeRate.Sources.Empty, prio: 2, id: :FACTORY, name: "Factory source"}
  ],
  # These are overridden by tests when it matters, but they still need to exist.
  rates_refresh_rate: 1_000 * 60,
  supported_refresh_rate: 1_000 * 60 * 60 * 24,
  request_timeout: 5_000,
  retry_timeout: 5_000,
  rates_ttl: 1_000 * 60 * 60,
  # These pairs are used by tests.
  fiat_to_update: [
    :EUR,
    :SEK,
    :USD
  ],
  extra_crypto_to_update: [:BTC, :BCH, :XMR, :DGC, :LTC]

config :bitpal, BitPal.Repo,
  username: "postgres",
  password: "postgres",
  database: "bitpal_test",
  hostname: "localhost",
  show_sensitive_data_on_connection_error: true,
  pool: Ecto.Adapters.SQL.Sandbox,
  # Try to avoid connection drop timeouts
  pool_size: 20,
  queue_target: 2_000

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :bitpal, BitPalApi.Endpoint,
  http: [port: 4001],
  server: false

config :bitpal, BitPalWeb.Endpoint,
  http: [port: 4002],
  server: false

# Only in tests, remove the complexity from the password hashing algorithm
config :argon2_elixir, t_cost: 1, m_cost: 8

# In test we don't send emails.
config :bitpal, BitPal.Mailer, adapter: Swoosh.Adapters.Test

config :bitpal, BitPalFactory, init: true
config :bitpal, BitPal.InvoiceSupervisor, pass_parent_pid: true

config :bitpal, BitPal.BackendMock, log_level: :alert

config :ex_unit, assert_receive_timeout: 500

config :logger, level: :error
