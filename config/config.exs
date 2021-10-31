import Config

# These are default values that can be overridden by settings.
# These should be overridable via BitPalSettings later
config :bitpal,
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

config :money, :custom_currencies, %{
  BCH: %{name: "Bitcoin Cash", exponent: 8, symbol: "BCH"},
  BTC: %{name: "Bitcoin", exponent: 8, symbol: "BTC"},
  DGC: %{name: "Dogecoin", exponent: 8, symbol: "DGC"},
  LTC: %{name: "Litecoin", exponent: 8, symbol: "LTC"},
  XMR: %{name: "Monero", exponent: 12, symbol: "XMR"}
}

config :master_proxy,
  # any Cowboy options are allowed
  http: [:inet6, port: 4000],
  # https: [:inet6, port: 4443],
  backends: [
    %{
      host: ~r{^api\.*.*$},
      phoenix_endpoint: BitPalApi.Endpoint
    },
    %{
      host: ~r/^.*$/,
      phoenix_endpoint: BitPalWeb.Endpoint
    }
  ]

config :bitpal, :ecto_repos, [BitPal.Repo]

secret_key_base = "3SPm+WOt8dvvlUgvtOh1cEFvlvuXunBvV0BN7vM30B0UQRedLXOmTLljlErX63Ba"
config :bitpal, secret_key_base: secret_key_base

config :bitpal, BitPalApi.Endpoint,
  url: [host: "localhost"],
  secret_key_base: secret_key_base,
  render_errors: [view: BitPalApi.ErrorView, accepts: ~w(json), layout: false],
  pubsub_server: BitPalApi.PubSub,
  live_view: [signing_salt: "L/r2fqOc"]

config :bitpal, BitPalWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: secret_key_base,
  render_errors: [view: BitPalWeb.ErrorView, accepts: ~w(html), layout: false],
  pubsub_server: BitPalWeb.PubSub,
  live_view: [signing_salt: "SIw7qWuU"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Pretty print for mix tasks (and some other pretty printing things)
config :scribe, style: Scribe.Style.Psql

# Configure esbuild assets pipeline
config :esbuild,
  version: "0.12.18",
  default: [
    args: ~w(js/app.js --bundle --target=es2016 --outdir=../priv/static/js),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Config sass conversion
config :dart_sass,
  version: "1.36.0",
  default: [
    args: ~w(css:../priv/static/css),
    cd: Path.expand("../assets", __DIR__)
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
