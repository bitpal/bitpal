defmodule BitPalSchemas.AddressKey do
  use TypedEctoSchema
  alias BitPalSchemas.Address
  alias BitPalSchemas.CurrencySettings
  alias BitPalSchemas.Currency

  typed_schema "address_keys" do
    field(:data, :string)
    timestamps()

    has_many(:addresses, Address)
    belongs_to(:currency, Currency, type: Ecto.Atom)
    belongs_to(:currency_settings, CurrencySettings)
  end
end
