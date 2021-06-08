defmodule BitPalSchemas.TxOutput do
  use Ecto.Schema
  alias BitPalSchemas.Address
  alias BitPalSchemas.Currency
  alias BitPalSchemas.Invoice
  alias Money.Ecto.NumericType

  @type txid :: String.t()

  @type t :: %__MODULE__{
          id: integer,
          txid: txid,
          amount: Money.t(),
          confirmed_height: non_neg_integer,
          double_spent: boolean,
          address_id: Address.id(),
          address: Address.t(),
          invoice: Invoice.t(),
          currency: Currency.t()
        }

  schema "tx_outputs" do
    field(:txid, :string)
    field(:amount, NumericType)
    field(:confirmed_height, :integer)
    field(:double_spent, :boolean, default: false)

    belongs_to(:address, Address, type: :string)
    has_one(:invoice, through: [:address, :invoice])
    has_one(:currency, through: [:address, :currency])
  end
end
