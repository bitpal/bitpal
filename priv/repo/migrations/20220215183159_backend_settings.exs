defmodule BitPal.Repo.Migrations.BackendSettings do
  use Ecto.Migration

  def change do
    create table(:backend_settings) do
      add :enabled, :boolean, null: false
      add :currency_id, references(:currencies, type: :string, size: 8), null: false
    end

    create unique_index(:backend_settings, :currency_id)
  end
end
