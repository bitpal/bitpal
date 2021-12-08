defmodule BitPalSchemas.CurrencySettings do
  use TypedEctoSchema
  alias BitPalSchemas.Currency
  alias BitPalSchemas.Store
  alias BitPalSchemas.AddressKey

  typed_schema "currency_settings" do
    field(:required_confirmations, :integer) :: non_neg_integer
    field(:double_spend_timeout, :integer) :: non_neg_integer
    has_one(:address_key, AddressKey)

    belongs_to(:store, Store)
    belongs_to(:currency, Currency, type: Ecto.Atom)
  end
end
