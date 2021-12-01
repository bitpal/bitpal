defmodule BitPalSchemas.AccessToken do
  use TypedEctoSchema
  alias BitPalSchemas.Store

  typed_schema "access_tokens" do
    field(:data, :string)
    field(:label, :string)

    # FIXME
    # valid until
    # created at

    belongs_to(:store, Store)
  end
end
