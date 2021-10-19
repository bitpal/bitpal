defmodule BitPal.Repo.Migrations.StoreSettings do
  use Ecto.Migration

  def change do
    create table(:currency_settings) do
      add :xpub, :string
      add :required_confirmations, :integer
      add :double_spend_timeout, :integer
      add :currency_id, references(:currencies, type: :string, size: 8), null: false
      add :store_id, references(:stores), null: false
    end

    create index(:currency_settings, :store_id)
    create unique_index(:currency_settings, [:store_id, :currency_id])
  end
end
