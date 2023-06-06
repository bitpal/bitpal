import Config

# Settings that should be controllable from the web UI

config :bitpal, BitPal.Backend.Monero,
  # 18081 for mainnet, 28081 for testnet and 38081 for stagenet
  net: :mainnet,
  daemon_ip: "localhost",
  daemon_port: 18081

config :bitpal, BitPal.BackendManager,
  restart_timeout: 3_000,
  enabled: [
    BitPal.Backend.Flowee,
    BitPal.Backend.Monero
  ]

config :bitpal, BitPal.ExchangeRate,
  sources: [
    {BitPal.ExchangeRate.Sources.Kraken, prio: 100},
    {BitPal.ExchangeRate.Sources.Coinbase, prio: 50},
    {BitPal.ExchangeRate.Sources.Coingecko, prio: 0}
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
  ]

# Fixed settings

config :bitpal, BitPalApi.Endpoint,
  force_ssl: [
    rewrite_on: [:x_forwarded_port, :x_forwarded_proto],
    hsts: true
  ]

config :bitpal, BitPalWeb.Endpoint,
  force_ssl: [
    rewrite_on: [:x_forwarded_port, :x_forwarded_proto],
    hsts: true
  ]

config :swoosh, api_client: Swoosh.ApiClient.Finch, finch_name: BitPal.Finch

config :logger, level: :info
