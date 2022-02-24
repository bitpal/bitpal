defmodule BitPalSchemas.BackendSettings do
  use TypedEctoSchema
  alias BitPalSchemas.Currency

  typed_schema "backend_settings" do
    field(:enabled, :boolean, default: true)
    belongs_to(:currency, Currency, type: Ecto.Atom)
  end
end
