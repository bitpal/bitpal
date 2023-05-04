defmodule BitPalSchemas.Currency do
  use TypedEctoSchema
  alias BitPalSchemas.Address
  alias BitPalSchemas.Invoice

  @type id :: atom

  @primary_key false
  typed_schema "currencies" do
    field(:id, Ecto.Atom, primary_key: true) :: id
    field(:block_height, :integer) :: non_neg_integer | nil
    has_many(:addresses, Address, references: :id)
    has_many(:invoices, Invoice, references: :id, foreign_key: :payment_currency_id)
    has_many(:tx_outputs, through: [:addresses, :tx_outputs])
  end
end
