defmodule BitPalSchemas.AddressKey do
  use TypedEctoSchema
  alias BitPalSchemas.Address
  alias BitPalSchemas.AddressKeyData
  alias BitPalSchemas.Currency
  alias BitPalSchemas.CurrencySettings

  @timestamps_opts [type: :utc_datetime]

  typed_schema "address_keys" do
    field(:data, AddressKeyData) :: AddressKeyData.t()
    timestamps()

    has_many(:addresses, Address)
    belongs_to(:currency, Currency, type: Ecto.Atom)
    belongs_to(:currency_settings, CurrencySettings)
  end
end
