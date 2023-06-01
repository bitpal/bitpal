import Config

# These are default values that can be overridden by settings.
# These should be overridable via BitPalSettings later
config :bitpal,
  required_confirmations: 0,
  double_spend_timeout: 2_000

config :money, :custom_currencies, %{
  BCH: %{name: "Bitcoin Cash", exponent: 8, symbol: "BCH"},
  BTC: %{name: "Bitcoin", exponent: 8, symbol: "BTC"},
  DGC: %{name: "Dogecoin", exponent: 8, symbol: "DGC"},
  LTC: %{name: "Litecoin", exponent: 8, symbol: "LTC"},
  XMR: %{name: "Monero", exponent: 12, symbol: "XMR"}
}

# Maybe in the future one might check what ports are used in the system
config :bitpal, BitPal.PortsHandler, available: 23000..23100

config :main_proxy,
  http: [:inet6, port: 4000]

# Needs a ssl keyfile
# https: [:inet6, port: 4443],

config :bitpal, :ecto_repos, [BitPal.Repo]

secret_key_base = "3SPm+WOt8dvvlUgvtOh1cEFvlvuXunBvV0BN7vM30B0UQRedLXOmTLljlErX63Ba"
config :bitpal, secret_key_base: secret_key_base

config :bitpal, BitPalApi.Endpoint,
  url: [host: "localhost"],
  secret_key_base: secret_key_base,
  render_errors: [
    formats: [json: BitPalApi.ErrorJSON],
    layout: false
  ],
  pubsub_server: BitPalApi.PubSub,
  live_view: [signing_salt: "L/r2fqOc"],
  server: false

config :bitpal, BitPalWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: secret_key_base,
  render_errors: [
    formats: [html: BitPalWeb.ErrorHTML],
    layout: false
  ],
  pubsub_server: BitPalWeb.PubSub,
  live_view: [signing_salt: "SIw7qWuU"],
  server: false

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
  version: "0.14.41",
  default: [
    args: ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/js),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Config sass conversion
config :dart_sass,
  version: "1.58.0",
  default: [
    args: ~w(css:../priv/static/css),
    cd: Path.expand("../assets", __DIR__)
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
