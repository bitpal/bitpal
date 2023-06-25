defmodule BitPalSchemas.Invoice do
  use TypedEctoSchema

  alias BitPalSchemas.Address
  alias BitPalSchemas.Currency
  alias BitPalSchemas.InvoiceRates
  alias BitPalSchemas.InvoiceStatus
  alias BitPalSchemas.Store
  alias Money.Ecto.NumericType

  @type id :: Ecto.UUID.t()

  @primary_key false
  typed_schema "invoices" do
    field(:id, :binary_id, autogenerate: true, primary_key: true) :: id

    # Tracks invoice status + status reason,
    # such as {:processing, :confirming}
    field(:status, InvoiceStatus) :: InvoiceStatus.t()

    # Price of invoice, can be specified in either fiat or crypto.
    # If specified in crypto, then it must match `payment_currency`.
    field(:price, NumericType) :: Money.t()

    # Valid exchange rates.
    # Filled with all supported rates upon creation.
    # A map from cryptocurrency -> fiat
    field(:rates, InvoiceRates) :: InvoiceRates.t()
    field(:rates_updated_at, :naive_datetime)

    # The amount + currency we're waiting for. Calculated from :rates and :payment_currency.
    field(:expected_payment, NumericType, virtual: true) :: Money.t() | nil
    # The cryptocurrency the invoice should be poid with.
    belongs_to(:payment_currency, Currency, type: Ecto.Atom)
    # The generated cryptocurrency address, matching the :payment_currency.
    belongs_to(:address, Address, type: :string, on_replace: :mark_as_invalid)
    # Any transactions related to the above address.
    has_many(:transactions, through: [:address, :tx_outputs, :transaction])
    # Outputs belonging to the address.
    has_many(:tx_outputs, through: [:address, :tx_outputs])
    # How many confirmations do we require?
    field(:required_confirmations, :integer) :: non_neg_integer | nil
    # When does the invoice expire?
    field(:valid_until, :utc_datetime) :: DateTime.t() | nil
    # When a status was reached
    field(:finalized_at, :utc_datetime) :: DateTime.t() | nil
    field(:paid_at, :utc_datetime) :: DateTime.t() | nil
    field(:uncollectible_at, :utc_datetime) :: DateTime.t() | nil

    # Calculated from transactions.
    field(:amount_paid, NumericType, virtual: true) :: Money.t() | nil
    field(:confirmations_due, :integer, virtual: true) :: non_neg_integer | nil

    # Description of the payment, displayed in payment uri and the customer's wallet.
    field(:description, :string)
    # Payee email, for payment notifications.
    field(:email, :string)
    # Order id, for association between a BitPal invoice and merchant pos system.
    field(:order_id, :string)
    # Pass through variable provided by the merchant, allows for arbitrary data storage.
    field(:pos_data, :map)

    # Payment uri, use to embed in QR codes or import directly into wallets.
    field(:payment_uri, :string)

    belongs_to(:store, Store)

    timestamps()
  end
end
