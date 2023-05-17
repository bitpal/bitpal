defmodule BitPal.Repo.Migrations.BlockHash do
  use Ecto.Migration

  def change do
    alter table(:currencies) do
      add :top_block_hash, :string
    end
  end
end
