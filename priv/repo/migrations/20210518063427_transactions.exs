defmodule BitPal.Repo.Migrations.Transactions do
  use Ecto.Migration

  def change do
    create table(:transactions, primary_key: false) do
      add :id, :string, primary_key: true
      add :amount, :money_with_currency, null: false
      add :confirmed_height, :integer
      add :double_spent, :boolean
      add :address_id, references(:addresses, type: :string)
      timestamps()
    end

    create unique_index(:transactions, :id)
  end
end
