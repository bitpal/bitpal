defmodule BitPal.Repo.Migrations.UserStoreRelation do
  use Ecto.Migration

  def change do
    create table(:users_stores, primary_key: false) do
      add :store_id, references(:stores)
      add :user_id, references(:users)
    end

    create unique_index(:stores, [:label])
  end
end
