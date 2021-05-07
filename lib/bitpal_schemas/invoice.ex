defmodule BitPalSchemas.Invoice do
  use Ecto.Schema
  alias BitPal.ExchangeRate
  alias BitPalSchemas.Address
  alias BitPalSchemas.Currency
  alias Money.Ecto.NumericType

  @type id :: Ecto.UUID.t()

  @type t :: %__MODULE__{
          id: id,
          amount: Money.t(),
          fiat_amount: Money.t(),
          exchange_rate: ExchangeRate.t(),
          currency_id: String.t(),
          currency: Currency.t(),
          address_id: String.t(),
          address: Address.t(),
          status: :pending | :confirmed | :rejected | :canceled,
          required_confirmations: non_neg_integer
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "invoices" do
    field(:amount, NumericType)
    field(:fiat_amount, NumericType)
    field(:exchange_rate, :map, virtual: true)
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
