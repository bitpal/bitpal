defmodule BitPalSchemas.Currency do
  use TypedEctoSchema
  alias BitPalSchemas.Address
  alias BitPalSchemas.Invoice
  alias BitPalSchemas.Transaction

  @type id :: atom

  @primary_key false
  typed_schema "currencies" do
    field(:id, Ecto.Atom, primary_key: true) :: id
    field(:block_height, :integer) :: non_neg_integer | nil
    field(:top_block_hash, :string) :: String.t() | nil
    has_many(:addresses, Address, references: :id)
    has_many(:transactions, Transaction, references: :id)
    has_many(:invoices, Invoice, references: :id, foreign_key: :payment_currency_id)
    has_many(:tx_outputs, through: [:addresses, :tx_outputs])
  end
end
