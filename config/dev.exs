use Mix.Config

# Configure your database
config :bitpal, BitPal.Repo,
  username: "postgres",
  password: "postgres",
  database: "payments_dev",
  hostname: "localhost",
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"
# Control log level
config :logger, level: :info

config :bitpal,
  # If you want to test live against the settings in config.exs, comment out the below:
  backends: [{BitPal.BackendMock, auto: true}]
