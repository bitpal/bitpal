# This file is responsible for configuring your umbrella
# and **all applications** and their dependencies with the
# help of Mix.Config.
#
# Note that all applications in your umbrella share the
# same configuration and dependencies, which is why they
# all use the same configuration file. If you want different
# configurations or dependencies per app, it is best to
# move said applications out of the umbrella.
use Mix.Config

config :master_proxy,
  # any Cowboy options are allowed
  http: [:inet6, port: 4000],
  # https: [:inet6, port: 4443],
  backends: [
    %{
      host: ~r{^demo\.bitpal.*$},
      phoenix_endpoint: Demo.Endpoint
    },
    %{
      host: ~r/^.*$/,
      # phoenix_endpoint: BitpalWeb.Endpoint
      phoenix_endpoint: Demo.Endpoint
    }
  ]

config :demo,
  generators: [context_app: false]

# Configures the endpoint
config :demo, Demo.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "3SPm+WOt8dvvlUgvtOh1cEFvlvuXunBvV0BN7vM30B0UQRedLXOmTLljlErX63Ba",
  render_errors: [view: Demo.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Demo.PubSub,
  live_view: [signing_salt: "bEctYJRI"],
  server: true

# Configure Mix tasks and generators
config :bitpal,
  ecto_repos: [BitPal.Repo],
  backends: [BitPal.Flowee]

config :bitpal_web,
  generators: [context_app: :bitpal]

# Configures the endpoint
config :bitpal_web, BitpalWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "+kRos2QRTovqRiGzeGAgG3lApk30rkna6tOPkHiG2+N9ohn5AqJteTPExZXoQtTW",
  render_errors: [view: BitpalWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Bitpal.PubSub,
  live_view: [signing_salt: "kY7BAgjm"],
  server: true

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configures which address to receive to
config :demo,
  address: "bitcoincash:qqpkcce4lzdc8guam5jfys9prfyhr90seqzakyv4tu"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
