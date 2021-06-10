defmodule BitPalSchemas.Address do
  use TypedEctoSchema
  alias BitPalSchemas.Currency
  alias BitPalSchemas.Invoice
  alias BitPalSchemas.TxOutput

  @primary_key {:id, :string, []}
  typed_schema "addresses" do
    field(:generation_index, :integer) :: non_neg_integer
    timestamps()

    belongs_to(:currency, Currency, type: :string)
    has_one(:invoice, Invoice)
    has_many(:tx_outputs, TxOutput)
  end
end
