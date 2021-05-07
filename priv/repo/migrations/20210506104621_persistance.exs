defmodule BitPal.Repo.Migrations.Persistance do
  use Ecto.Migration

  def change do
    execute "CREATE TYPE public.money_with_currency AS (amount NUMERIC, currency VARCHAR)",
            "DROP TYPE public.money_with_currency"

    create table(:currencies, primary_key: false) do
      add :id, :string, size: 8, primary_key: true
    end

    create unique_index(:currencies, :id)

    create table(:addresses, primary_key: false) do
      add :id, :string, primary_key: true
      add :generation_index, :integer
      add :currency_id, references(:currencies, type: :string, size: 8), null: false
      timestamps()
    end

    create unique_index(:addresses, :id)
    create unique_index(:addresses, [:generation_index, :currency_id])

    create table(:invoices, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :amount, :money_with_currency, null: false
      add :fiat_amount, :money_with_currency
      add :status, :string
      add :required_confirmations, :integer
      add :currency_id, references(:currencies, type: :string, size: 8), null: false
      add :address_id, references(:addresses, type: :string)
      timestamps()
    end

    create unique_index(:invoices, :id)
  end
end
