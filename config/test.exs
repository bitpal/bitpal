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

# Only in tests, remove the complexity from the password hashing algorithm
config :argon2_elixir, t_cost: 1, m_cost: 8

# In test we don't send emails.
config :bitpal, BitPal.Mailer, adapter: Swoosh.Adapters.Test

# Fallback for testing
config :bitpal,
  xpub:
    "xpub6C23JpFE6ABbBudoQfwMU239R5Bm6QGoigtLq1BD3cz3cC6DUTg89H3A7kf95GDzfcTis1K1m7ypGuUPmXCaCvoxDKbeNv6wRBEGEnt1NV7"

# Print only warnings and errors during test
config :logger, level: :warn
