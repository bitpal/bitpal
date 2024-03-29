defmodule BitPalSchemas.Address do
  use TypedEctoSchema
  alias BitPalSchemas.AddressKey
  alias BitPalSchemas.Currency
  alias BitPalSchemas.Invoice
  alias BitPalSchemas.TxOutput

  @timestamps_opts [type: :utc_datetime]

  @type id :: String.t()

  @primary_key {:id, :string, []}
  typed_schema "addresses" do
    field(:address_index, :integer) :: non_neg_integer
    timestamps()

    belongs_to(:currency, Currency, type: Ecto.Atom)
    belongs_to(:address_key, AddressKey)
    has_one(:invoice, Invoice)
    has_many(:tx_outputs, TxOutput)
    has_many(:transactions, through: [:tx_outputs, :transaction])
  end
end
