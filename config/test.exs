use Mix.Config

config :bitpal,
  # Backends should be specified per test
  backends: [],
  # Mocked http requests
  http_client: BitPal.TestHTTPClient

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :bitpal, BitPal.Repo,
  username: "postgres",
  password: "postgres",
  database: "payments_test#{System.get_env("MIX_TEST_PARTITION")}",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

# Print only warnings and errors during test
config :logger, level: :warn
