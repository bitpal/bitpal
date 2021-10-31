defmodule BitPalSchemas.Address do
  use TypedEctoSchema
  alias BitPalSchemas.Currency
  alias BitPalSchemas.Invoice
  alias BitPalSchemas.TxOutput
  alias BitPalSchemas.AddressKey

  @type id :: String.t()

  @primary_key {:id, :string, []}
  typed_schema "addresses" do
    field(:address_index, :integer) :: non_neg_integer
    timestamps()

    belongs_to(:currency, Currency, type: Ecto.Atom)
    belongs_to(:address_key, AddressKey)
    has_one(:invoice, Invoice)
    has_many(:tx_outputs, TxOutput)
  end
end
