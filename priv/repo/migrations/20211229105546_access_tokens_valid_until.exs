defmodule BitPal.Repo.Migrations.AccessTokensValidUntil do
  use Ecto.Migration

  def change do
    alter table(:access_tokens) do
      add :valid_until, :naive_datetime
      add :last_accessed, :naive_datetime
      timestamps(updated_at: false, inserted_at: :created_at)
    end
  end
end
