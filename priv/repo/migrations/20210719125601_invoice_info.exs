defmodule BitPal.Repo.Migrations.InvoiceInfo do
  use Ecto.Migration

  def change do
    alter table(:invoices) do
      add :email, :string
      add :pos_data, :map
      add :status_reason, :string
    end
  end
end
