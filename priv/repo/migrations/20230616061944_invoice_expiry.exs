defmodule BitPal.Repo.Migrations.InvoiceExpiry do
  use Ecto.Migration

  def change do
    alter table(:invoices) do
      add :valid_until, :utc_datetime
    end

    alter table(:currency_settings) do
      add :invoice_valid_time, :integer
    end
  end
end
