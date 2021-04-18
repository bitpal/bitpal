use Mix.Config

config :bitpal,
  ecto_repos: [BitPal.Repo],
  backends: [BitPal.Backend.Flowee]

config :bitpal, BitPal.ExchangeRate, backends: [BitPal.ExchangeRate.Kraken]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
