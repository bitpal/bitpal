defmodule BitPalSchemas.Address do
  use Ecto.Schema
  alias BitPalSchemas.Currency
  alias BitPalSchemas.Invoice

  @type t :: %__MODULE__{
          id: String.t(),
          generation_index: non_neg_integer(),
          currency_id: String.t(),
          currency: Currency.t()
        }

  @primary_key {:id, :string, []}
  schema "addresses" do
    field(:generation_index, :integer)
    timestamps()

    belongs_to(:currency, Currency, type: :string, references: :ticker)
    has_many(:invoices, Invoice)
  end
end
