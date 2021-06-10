defmodule BitPalSchemas.Currency do
  use TypedEctoSchema
  alias BitPalSchemas.Address
  alias BitPalSchemas.Invoice

  @type id :: String.t()

  @primary_key {:id, :string, []}
  typed_schema "currencies" do
    field(:block_height, :integer) :: non_neg_integer | nil
    has_many(:addresses, Address)
    has_many(:invoices, Invoice)
    has_many(:tx_outputs, through: [:addresses, :tx_outputs])
  end
end
