import Config

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
  render_errors: [view: BitPalWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: BitPalWeb.PubSub,
  live_view: [signing_salt: "SIw7qWuU"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
