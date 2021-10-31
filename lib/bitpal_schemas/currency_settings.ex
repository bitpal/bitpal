defmodule BitPalSchemas.CurrencySettings do
  use TypedEctoSchema
  alias BitPalSchemas.Currency
  alias BitPalSchemas.Store
  alias BitPalSchemas.AddressKey

  typed_schema "currency_settings" do
    field(:required_confirmations, :integer)
    field(:double_spend_timeout, :integer)
    has_one(:address_key, AddressKey)

    belongs_to(:store, Store)
    belongs_to(:currency, Currency, type: Ecto.Atom)
  end
end
