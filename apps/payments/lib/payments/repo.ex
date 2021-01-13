defmodule Payments.Repo do
  use Ecto.Repo,
    otp_app: :payments,
    adapter: Ecto.Adapters.Postgres
end
