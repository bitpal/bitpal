defmodule BitPalSchemas.Transaction do
  use TypedEctoSchema
  alias BitPalSchemas.Currency
  alias BitPalSchemas.TxOutput

  @type id :: String.t()
  @type height :: non_neg_integer

  @primary_key false
  typed_schema "transactions" do
    field(:id, :string, autogenerate: false, primary_key: true) :: id
    field(:height, :integer, default: 0) :: height
    field(:failed, :boolean, default: false)
    field(:double_spent, :boolean, default: false)
    timestamps(updated_at: false)

    belongs_to(:currency, Currency, type: Ecto.Atom)
    has_many(:outputs, TxOutput, references: :id)
  end
end
