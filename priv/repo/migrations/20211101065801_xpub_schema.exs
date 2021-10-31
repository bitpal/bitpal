defmodule BitPal.Repo.Migrations.XpubSchema do
  use Ecto.Migration

  def change do
    create table(:address_keys) do
      add :data, :string, null: false
      add :currency_id, references(:currencies, type: :string, size: 8), null: false
      add :currency_settings_id, references(:currency_settings)
      timestamps()
    end

    create unique_index(:address_keys, :data)
    create index(:address_keys, :currency_settings_id)

    alter table(:currency_settings) do
      remove :xpub
    end

    drop unique_index(:addresses, [:generation_index, :currency_id])

    alter table(:addresses) do
      add :address_key_id, references(:address_keys), null: false
      add :address_index, :integer, null: false
      remove :generation_index
    end

    create unique_index(:addresses, [:address_index, :address_key_id])
    create index(:addresses, :address_key_id)
  end
end
