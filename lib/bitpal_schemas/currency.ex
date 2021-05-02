defmodule BitPalSchemas.Currency do
  use Ecto.Schema
  alias BitPalSchemas.Address
  alias BitPalSchemas.Invoice

  @type ticker :: atom | String.t()

  @type t :: %__MODULE__{
          ticker: ticker,
          addresses: [Address.t()],
          invoices: [Invoice.t()]
        }

  @primary_key {:ticker, :string, []}
  schema "currencies" do
    has_many(:addresses, Address, foreign_key: :currency_id)
    has_many(:invoices, Invoice, foreign_key: :currency_id)
  end
end
