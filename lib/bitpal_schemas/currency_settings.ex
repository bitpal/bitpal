defmodule BitPalSchemas.CurrencySettings do
  use TypedEctoSchema
  alias BitPalSchemas.Currency
  alias BitPalSchemas.Store

  typed_schema "currency_settings" do
    # FIXME Here we should track address index per xpub
    # And each store needs to use different xpubs...
    field(:xpub, :string)
    field(:required_confirmations, :integer)
    field(:double_spend_timeout, :integer)

    belongs_to(:store, Store)
    belongs_to(:currency, Currency, type: Ecto.Atom)
  end
end
