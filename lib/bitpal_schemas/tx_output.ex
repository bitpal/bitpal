defmodule BitPalSchemas.TxOutput do
  use TypedEctoSchema
  alias BitPalSchemas.Address
  alias Money.Ecto.NumericType

  @type txid :: String.t()
  @type height :: non_neg_integer | nil

  # FIXME create a tx / tx_output sckemas?
  typed_schema "tx_outputs" do
    field(:txid, :string)
    field(:amount, NumericType) :: Money.t()
    field(:confirmed_height, :integer) :: height
    # field(:required_confirmations, :integer) :: non_neg_integer
    # field(:failed, :boolean, default: false)
    field(:double_spent, :boolean, default: false)

    belongs_to(:address, Address, type: :string)
    has_one(:invoice, through: [:address, :invoice])
    has_one(:currency, through: [:address, :currency])
  end
end
