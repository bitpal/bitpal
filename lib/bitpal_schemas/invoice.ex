defmodule BitPalSchemas.Invoice do
  use TypedEctoSchema

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
  alias Money.Ecto.NumericType

  @type id :: Ecto.UUID.t()
  @type status :: :draft | :open | :processing | :uncollectible | :void | :paid

  @primary_key false
  typed_schema "invoices" do
    field(:id, :binary_id, autogenerate: true, primary_key: true) :: id
    field(:amount, NumericType) :: Money.t() | nil
    field(:fiat_amount, NumericType) :: Money.t() | nil
    field(:exchange_rate, :map, virtual: true) :: ExchangeRate.t() | nil
    field(:required_confirmations, :integer, default: 0) :: non_neg_integer
    field(:description, :string)
    # field(:payment_uri, :string, virtual: true)
    field(:amount_paid, NumericType, virtual: true) :: Money.t() | nil

    # NOTE maybe we should create our own custom Enum type, to not separate field declaration
    # from state transitions?
    field(:status, Ecto.Enum,
      values: [:draft, :open, :processing, :uncollectible, :void, :paid],
      default: :draft
    ) :: status

    timestamps()

    belongs_to(:address, Address, type: :string, on_replace: :mark_as_invalid)
    belongs_to(:currency, Currency, type: Ecto.Atom)
    has_many(:tx_outputs, through: [:address, :tx_outputs])
  end
end
