defmodule BitPalSchemas.Store do
  use TypedEctoSchema
  alias BitPalSchemas.AccessToken
  alias BitPalSchemas.Invoice

  @type id :: integer

  typed_schema "stores" do
    field(:label, :string)

    has_many(:invoices, Invoice, references: :id)
    has_many(:access_tokens, AccessToken)
  end
end
