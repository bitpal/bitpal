defmodule BitPal.Repo.Migrations.PaymentUri do
  use Ecto.Migration

  def change do
    alter table(:stores) do
      add :recipient_name, :string
    end

    alter table(:invoices) do
      add :payment_uri, :string
    end
  end
end
