defmodule BitPalSchemas.CurrencySettings do
  use TypedEctoSchema
  alias BitPalSchemas.AddressKey
  alias BitPalSchemas.Currency
  alias BitPalSchemas.Store

  typed_schema "currency_settings" do
    field(:required_confirmations, :integer) :: non_neg_integer
    # Time to wait before accepting a double spend, in seconds.
    field(:double_spend_timeout, :integer) :: non_neg_integer
    # How long before an invoice should expire, in seconds.
    field(:invoice_valid_time, :integer) :: non_neg_integer
    has_one(:address_key, AddressKey)

    belongs_to(:store, Store)
    belongs_to(:currency, Currency, type: Ecto.Atom)
  end
end
