defmodule BitPal.Repo.Migrations.SetupState do
  use Ecto.Migration

  def change do
    create table(:setup_state) do
      add :state, :string, null: false
    end
  end
end
