import Config

if config_env() == :prod do
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  config :bitpal, secret_key_base: secret_key_base
  config :bitpal, BitPalApi.Endpoint, secret_key_base: secret_key_base
  config :bitpal, BitPalWeb.Endpoint, secret_key_base: secret_key_base

  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  config :bitpal, BitPal.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

  port = String.to_integer(System.get_env("PORT") || "4000")

  config :main_proxy,
    http: [:inet6, port: port]

  host =
    System.get_env("PHX_HOST") ||
      raise """
      environment variable PHX_HOST is missing.
      For example: mydomain.com
      """

  check_origin = [
    "https://#{host}",
    "https://#{host}:#{port}"
  ]

  config :bitpal, BitPalApi.Endpoint,
    check_origin: check_origin,
    url: [host: host]

  config :bitpal, BitPalWeb.Endpoint,
    check_origin: check_origin,
    url: [host: host]

  config :bitpal, BitPal.Mailer,
    adapter: Swoosh.Adapters.SMTP,
    relay: "smtp.fastmail.com",
    # ssl: true,
    # port: 465,
    # Use STARTTLS because some providers block port 465
    ssl: false,
    port: 587,
    tls: :if_available,
    auth: :always,
    retries: 2,
    no_mx_lookups: false,
    username: System.get_env("EMAIL_USERNAME"),
    password: System.get_env("EMAIL_PASSWORD")
end
