defmodule BitPalSchemas.Invoice do
  use Ecto.Schema
  alias BitPalSchemas.Address
  alias BitPalSchemas.Currency

  @type id :: Ecto.UUID.t()

  @type t :: %__MODULE__{
          id: id,
          # FIXME custom types here
          # FIXME need to store fiat ticker somehow
          amount: Decimal.t(),
          fiat_amount: Decimal.t(),
          exchange_rate: Decimal.t(),
          currency_id: String.t(),
          currency: Currency.t(),
          address_id: String.t(),
          address: Address.t()
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "invoices" do
    field(:amount, :decimal)
    field(:fiat_amount, :decimal)
    field(:exchange_rate, :decimal, virtual: true)
    # FIXME not virtual, or stored somewhere else?
    field(:required_confirmations, :integer, default: 0)

    field(:status, Ecto.Enum,
      values: [:pending, :confirmed, :rejected, :canceled],
      default: :pending
    )

    timestamps()

    belongs_to(:address, Address, type: :string, on_replace: :mark_as_invalid)
    belongs_to(:currency, Currency, type: :string, references: :ticker)
  end
end
