defmodule BitPalSchemas.Invoice do
  use Ecto.Schema
  alias BitPalSchemas.Address
  alias BitPalSchemas.Currency
  alias BitPalSchemas.ExchangeRateType

  @type id :: Ecto.UUID.t()

  @type t :: %__MODULE__{
          id: id,
          amount: Decimal.t(),
          fiat_amount: Decimal.t(),
          exchange_rate: {Decimal.t(), String.t()},
          currency_id: String.t(),
          currency: Currency.t(),
          address_id: String.t(),
          address: Address.t(),
          status: :pending | :confirmed | :rejected | :canceled,
          required_confirmations: non_neg_integer
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "invoices" do
    field(:amount, :decimal)
    field(:fiat_amount, :decimal, virtual: true)
    field(:exchange_rate, ExchangeRateType)
    field(:required_confirmations, :integer, default: 0)

    field(:status, Ecto.Enum,
      values: [:pending, :confirmed, :rejected, :canceled],
      default: :pending
    )

    timestamps()

    belongs_to(:address, Address, type: :string, on_replace: :mark_as_invalid)
    belongs_to(:currency, Currency, type: :string)
  end
end
