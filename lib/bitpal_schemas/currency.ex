defmodule BitPalSchemas.Currency do
  use Ecto.Schema
  alias BitPalSchemas.Address
  alias BitPalSchemas.Invoice

  @type id :: atom | String.t()

  @type t :: %__MODULE__{
          id: id,
          addresses: [Address.t()],
          invoices: [Invoice.t()]
        }

  @primary_key {:id, :string, []}
  schema "currencies" do
    has_many(:addresses, Address)
    has_many(:invoices, Invoice)
    has_many(:tx_outputs, through: [:addresses, :tx_outputs])
  end
end
