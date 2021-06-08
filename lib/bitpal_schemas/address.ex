defmodule BitPalSchemas.Address do
  use Ecto.Schema
  alias BitPalSchemas.Currency
  alias BitPalSchemas.Invoice
  alias BitPalSchemas.TxOutput

  @type id :: String.t()
  @type t :: %__MODULE__{
          id: id,
          generation_index: non_neg_integer(),
          currency_id: String.t(),
          currency: Currency.t(),
          tx_outputs: [TxOutput.t()]
        }

  @primary_key {:id, :string, []}
  schema "addresses" do
    field(:generation_index, :integer)
    timestamps()

    belongs_to(:currency, Currency, type: :string)
    has_one(:invoice, Invoice)
    has_many(:tx_outputs, TxOutput)
  end
end
