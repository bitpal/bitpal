defmodule BitPal.Repo do
  use Ecto.Repo,
    otp_app: :payments,
    adapter: Ecto.Adapters.Postgres
end
