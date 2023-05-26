defmodule BitPal.Repo.Migrations.NewBeginning do
  use Ecto.Migration

  # During development these migrations were split up,
  # but after a big rewrite the alterations were so big,
  # and BitPal wasn't released yet, so I decided to merge them all into one.

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", ""

    execute "CREATE TYPE public.money_with_currency AS (amount NUMERIC, currency VARCHAR)",
            "DROP TYPE public.money_with_currency"

    create table(:setup_state) do
      add :state, :string, null: false
    end

    create table(:stores) do
      add :label, :string, null: false
      add :slug, :string, null: false
    end

    create unique_index(:stores, :slug)

    create table(:users) do
      add :email, :citext, null: false
      add :hashed_password, :string, null: false
      add :confirmed_at, :naive_datetime
      timestamps()
    end

    create unique_index(:users, [:email])

    create table(:users_stores, primary_key: false) do
      add :store_id, references(:stores)
      add :user_id, references(:users)
    end

    create unique_index(:stores, [:label])

    create table(:users_tokens) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string
      timestamps(updated_at: false)
    end

    create table(:access_tokens) do
      add :data, :string, null: false
      add :label, :string
      add :store_id, references(:stores), null: false
      add :valid_until, :naive_datetime
      add :last_accessed, :naive_datetime
      timestamps(updated_at: false, inserted_at: :created_at)
    end

    create unique_index(:access_tokens, :data)

    create index(:users_tokens, [:user_id])
    create unique_index(:users_tokens, [:context, :token])

    create table(:currencies, primary_key: false) do
      add :id, :string, size: 8, primary_key: true
      add :block_height, :integer
      add :top_block_hash, :string
    end

    create unique_index(:currencies, :id)

    create table(:currency_settings) do
      add :required_confirmations, :integer
      add :double_spend_timeout, :integer
      add :currency_id, references(:currencies, type: :string, size: 8), null: false
      add :store_id, references(:stores), null: false
    end

    create index(:currency_settings, :store_id)
    create unique_index(:currency_settings, [:store_id, :currency_id])

    create table(:address_keys) do
      add :data, :map, null: false
      add :currency_id, references(:currencies, type: :string, size: 8), null: false
      add :currency_settings_id, references(:currency_settings)
      timestamps()
    end

    execute("CREATE UNIQUE INDEX address_keys_xpub_idx ON address_keys((data->'xpub'));")

    execute(
      "CREATE UNIQUE INDEX address_keys_viewkey_idx ON address_keys((data->'viewkey'), (data->'address'), (data->'account'));"
    )

    create index(:address_keys, :currency_settings_id)

    create table(:addresses, primary_key: false) do
      add :id, :string, primary_key: true
      add :address_key_id, references(:address_keys), null: false
      add :address_index, :integer, null: false
      add :currency_id, references(:currencies, type: :string, size: 8), null: false
      timestamps()
    end

    create unique_index(:addresses, :id)
    create unique_index(:addresses, [:address_index, :address_key_id])
    create index(:addresses, :address_key_id)

    create table(:transactions, primary_key: false) do
      add :id, :string, primary_key: true
      add :height, :integer, null: false
      add :failed, :boolean, null: false
      add :double_spent, :boolean, null: false
      add :currency_id, references(:currencies, type: :string, size: 8), null: false
      timestamps(updated_at: false)
    end

    create unique_index(:transactions, :id)

    create table(:tx_outputs) do
      add :amount, :money_with_currency, null: false
      add :address_id, references(:addresses, type: :string), null: false
      add :transaction_id, references(:transactions, type: :string), null: false
    end

    create table(:backend_settings) do
      add :enabled, :boolean, null: false
      add :currency_id, references(:currencies, type: :string, size: 8), null: false
    end

    create unique_index(:backend_settings, :currency_id)

    create table(:invoices, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :status, :map, null: false
      add :price, :money_with_currency, null: false

      add :rates, :map, null: false
      add :rates_updated_at, :naive_datetime, null: false

      add :payment_currency_id, references(:currencies, type: :string, size: 8)
      add :address_id, references(:addresses, type: :string)
      add :required_confirmations, :integer

      add :description, :string
      add :email, :string
      add :order_id, :string
      add :pos_data, :map

      add :store_id, references(:stores), null: false
      timestamps()
    end

    create unique_index(:invoices, :id)
    execute("CREATE INDEX ON invoices((status->'state'));")

    create table(:exchange_rates) do
      add :rate, :decimal, null: false
      add :base, :string, size: 8, null: false
      add :quote, :string, size: 8, null: false

      add :source, :string, null: false
      add :prio, :integer, null: false

      timestamps(inserted_at: false)
    end

    create unique_index(:exchange_rates, [:base, :quote, :source])
    create index(:exchange_rates, [:base, :quote])
  end
end
