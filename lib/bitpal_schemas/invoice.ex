defmodule BitPalSchemas.Invoice do
  use Ecto.Schema

  use BitPal.FSM.Config,
    state_field: :status,
    transitions: %{
      :draft => :open,
      :open => [:processing, :uncollectible, :void],
      :processing => [:paid, :uncollectible],
      :uncollectible => [:paid, :void]
    }

  alias BitPal.ExchangeRate
  alias BitPalSchemas.Address
  alias BitPalSchemas.Currency
  alias BitPalSchemas.TxOutput
  alias Money.Ecto.NumericType

  @type id :: Ecto.UUID.t()
  @type status :: :draft | :open | :processing | :uncollectible | :void | :paid

  @type t :: %__MODULE__{
          id: id,
          amount: Money.t(),
          fiat_amount: Money.t(),
          exchange_rate: ExchangeRate.t(),
          currency_id: String.t(),
          currency: Currency.t(),
          address_id: String.t(),
          address: Address.t(),
          tx_outputs: [TxOutput.t()],
          status: status,
          required_confirmations: non_neg_integer,
          description: String.t()
          # payment_uri: String.t()
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "invoices" do
    field(:amount, NumericType)
    field(:fiat_amount, NumericType)
    field(:exchange_rate, :map, virtual: true)
    field(:required_confirmations, :integer, default: 0)
    field(:description, :string)
    # field(:payment_uri, :string, virtual: true)
    field(:amount_paid, NumericType, virtual: true)

    # NOTE maybe we should create our own custom Enum type, to not separate field declaration
    # from state transitions?
    field(:status, Ecto.Enum,
      values: [:draft, :open, :processing, :uncollectible, :void, :paid],
      default: :draft
    )

    timestamps()

    belongs_to(:address, Address, type: :string, on_replace: :mark_as_invalid)
    belongs_to(:currency, Currency, type: :string)
    has_many(:tx_outputs, through: [:address, :tx_outputs])
  end
end
