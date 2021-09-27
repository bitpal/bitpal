use Mix.Config

config :bitpal, BitPal.Repo,
  username: "postgres",
  password: "postgres",
  database: "bitpal_dev",
  hostname: "localhost",
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :bitpal, BitPalApi.Endpoint,
  http: [port: 4001],
  debug_errors: false,
  code_reloader: true,
  check_origin: false

config :bitpal, BitPalWeb.Endpoint,
  http: [port: 4002],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]},
    sass: {
      DartSass,
      :install_and_run,
      [:default, ~w(--embed-source-map --source-map-urls=absolute --watch)]
    }
  ]

# Watch static and templates for browser reloading.
config :bitpal, BitPalWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"lib/bitpal_web/(live|views)/.*(ex)$",
      ~r"lib/bitpal_web/templates/.*(eex)$"
    ]
  ]

config :bitpal, :enable_live_dashboard, true

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime
