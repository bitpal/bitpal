defmodule BitPal.Repo.Migrations.InitialInvoice do
  use Ecto.Migration

  def change do
    # execute "CREATE TYPE public.money AS (amount integer, ticker char(8))",
    #         "DROP TYPE public.money"

    create table(:currencies, primary_key: false) do
      add :ticker, :string, size: 8, primary_key: true
    end

    create unique_index(:currencies, :ticker)

    create table(:addresses, primary_key: false) do
      add :id, :string, primary_key: true
      add :generation_index, :integer
      add :currency_id, references(:currencies, type: :string, column: :ticker), null: false
      timestamps()
    end

    create unique_index(:addresses, :id)
    create unique_index(:addresses, [:generation_index, :currency_id])

    create table(:invoices, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :amount, :decimal, null: false
      add :fiat_amount, :decimal
      add :status, :string
      add :required_confirmations, :integer
      add :currency_id, references(:currencies, type: :string, column: :ticker), null: false
      add :address_id, references(:addresses, type: :string)
      timestamps()
    end

    create unique_index(:invoices, :id)
  end
end
