defmodule BitPal.Repo.Migrations.AccessTokensValidUntil do
  use Ecto.Migration

  def change do
    alter table(:access_tokens) do
      add :valid_until, :naive_datetime
      add :last_accessed, :naive_datetime
    end
  end
end
