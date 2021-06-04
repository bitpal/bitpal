defmodule BitPalSchemas.Transaction do
  use Ecto.Schema
  alias BitPalSchemas.Address
  alias BitPalSchemas.Currency
  alias BitPalSchemas.Invoice
  alias Money.Ecto.NumericType

  @type id :: String.t()

  @type t :: %__MODULE__{
          id: id,
          amount: Money.t(),
          confirmed_height: non_neg_integer,
          double_spent: boolean,
          address_id: Address.id(),
          address: Address.t(),
          invoice: Invoice.t(),
          currency: Currency.t()
        }

  @primary_key {:id, :string, []}
  schema "transactions" do
    field(:amount, NumericType)
    field(:confirmed_height, :integer)
    field(:double_spent, :boolean, default: false)
    # field(:double_spend_timeout, :boolean, default: false, virtual: true)
    timestamps()

    belongs_to(:address, Address, type: :string)
    has_one(:invoice, through: [:address, :invoice])
    has_one(:currency, through: [:address, :currency])
  end
end
