# defmodule BitPalSchemas.Transaction do
#   use Ecto.Schema
#   alias BitPalSchemas.{Invoice, Currency}
#
#   schema "transactions" do
#     field(:txid, :binary_id, primary_key: true)
#     field(:address_index, :integer)
#     field(:status, Ecto.Enum, values: [:pending, :confirmed, :rejected])
#     timestamps()
#
#     belongs_to(:invoice, Invoice)
#     belongs_to(:currency, Currency)
#   end
# end
