defmodule BitPal.Repo.Migrations.StoresAccessTokens do
  use Ecto.Migration

  def change do
    create table(:stores) do
      add :label, :string
    end

    create table(:access_tokens) do
      add :data, :string, null: false
      add :label, :string
      add :store_id, references(:stores), null: false
    end

    create unique_index(:access_tokens, :data)

    alter table(:invoices) do
      add :store_id, references(:stores), null: false
    end
  end
end
