defmodule BitPal.Repo do
  use Ecto.Repo,
    otp_app: :bitpal,
    adapter: Ecto.Adapters.Postgres
end
