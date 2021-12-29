defmodule BitPal.Repo.Migrations.StoreSlugs do
  use Ecto.Migration

  def change do
    alter table(:stores) do
      modify :label, :string, null: false
      add :slug, :string, null: false
    end

    create unique_index(:stores, :slug)
  end
end
