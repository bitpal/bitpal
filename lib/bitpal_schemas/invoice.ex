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
  alias BitPalSchemas.Store
  alias Money.Ecto.NumericType

  @type id :: Ecto.UUID.t()
  @type status :: :draft | :open | :processing | :uncollectible | :void | :paid
  @type status_reason ::
          :expired | :canceled | :double_spent | :timed_out | :verifying | :confirming | nil

  @primary_key false
  typed_schema "invoices" do
    field(:id, :binary_id, autogenerate: true, primary_key: true) :: id

    # Amount to pay
    field(:amount, NumericType) :: Money.t() | nil
    field(:fiat_amount, NumericType) :: Money.t() | nil
    field(:exchange_rate, :map, virtual: true) :: ExchangeRate.t() | nil

    # Settings
    # NOTE this should probably be per tx
    field(:required_confirmations, :integer, default: 0) :: non_neg_integer

    # Extra information
    # Description of the payment, displayed in payment uri and the customer's wallet
    field(:description, :string)
    field(:email, :string)
    # Passthru variable provided by the merchant, allows for arbitrary data storage.
    field(:pos_data, :map)

    # field(:payment_uri, :string, virtual: true)

    # Calculated from transactions
    field(:amount_paid, NumericType, virtual: true) :: Money.t() | nil
    field(:confirmations_due, :integer, virtual: true) :: non_neg_integer | nil

    # NOTE maybe we should create our own custom Enum type, to not separate field declaration
    # from state transitions?
    field(:status, Ecto.Enum,
      values: [:draft, :open, :processing, :uncollectible, :void, :paid],
      default: :draft
    ) :: status

    # Why did we enter the current status?
    field(:status_reason, Ecto.Enum,
      values: [:expired, :canceled, :double_spent, :timed_out, :verifying, :confirming]
    ) :: status_reason

    timestamps()

    belongs_to(:store, Store)
    belongs_to(:address, Address, type: :string, on_replace: :mark_as_invalid)
    belongs_to(:currency, Currency, type: Ecto.Atom)
    has_many(:tx_outputs, through: [:address, :tx_outputs])
  end
end
