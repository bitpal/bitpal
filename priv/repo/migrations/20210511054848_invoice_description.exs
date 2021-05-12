defmodule BitPal.Repo.Migrations.InvoiceDescription do
  use Ecto.Migration

  def change do
    alter table(:invoices) do
      add :description, :string
    end
  end
end
