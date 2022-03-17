import Config

if Config.config_env() == :prod do
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
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")
end
