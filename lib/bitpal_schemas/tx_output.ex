defmodule BitPalSchemas.TxOutput do
  use TypedEctoSchema
  alias BitPalSchemas.Address
  alias BitPalSchemas.Transaction
  alias Money.Ecto.NumericType

  @type txid :: String.t()

  typed_schema "tx_outputs" do
    field(:amount, NumericType) :: Money.t()

    belongs_to(:transaction, Transaction, type: :string)
    belongs_to(:address, Address, type: :string)
    has_one(:invoice, through: [:address, :invoice])
    has_one(:currency, through: [:transaction, :currency])
  end
end
