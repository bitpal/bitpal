defmodule BitPal.Repo.Migrations.UtcDatetimes do
  use Ecto.Migration

  def change do
    alter table(:users) do
      modify :confirmed_at, :utc_datetime, from: :naive_datetime
      modify :inserted_at, :utc_datetime, from: :naive_datetime
      modify :updated_at, :utc_datetime, from: :naive_datetime
    end

    alter table(:users_tokens) do
      modify :inserted_at, :utc_datetime, from: :naive_datetime
    end

    alter table(:access_tokens) do
      modify :valid_until, :utc_datetime, from: :naive_datetime
      modify :last_accessed, :utc_datetime, from: :naive_datetime
      modify :created_at, :utc_datetime, from: :naive_datetime
    end

    alter table(:address_keys) do
      modify :inserted_at, :utc_datetime, from: :naive_datetime
      modify :updated_at, :utc_datetime, from: :naive_datetime
    end

    alter table(:addresses) do
      modify :inserted_at, :utc_datetime, from: :naive_datetime
      modify :updated_at, :utc_datetime, from: :naive_datetime
    end

    alter table(:transactions) do
      modify :inserted_at, :utc_datetime, from: :naive_datetime
    end

    alter table(:exchange_rates) do
      modify :updated_at, :utc_datetime, from: :naive_datetime
    end

    alter table(:invoices) do
      modify :rates_updated_at, :utc_datetime, from: :naive_datetime
      modify :inserted_at, :utc_datetime, from: :naive_datetime
      remove :updated_at, :naive_datetime
    end

    rename table(:invoices), :inserted_at, to: :created_at
  end
end
