use Mix.Config

config :bitpal, BitPal.Repo,
  username: "postgres",
  password: "postgres",
  database: "bitpal_test",
  hostname: "localhost",
  show_sensitive_data_on_connection_error: true,
  pool: Ecto.Adapters.SQL.Sandbox

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :bitpal, BitPalApi.Endpoint,
  http: [port: 4001],
  server: false

config :bitpal, BitPalWeb.Endpoint,
  http: [port: 4002],
  server: false

config :bitpal, :enable_live_dashboard, true

# Print only warnings and errors during test
config :logger, level: :warn
