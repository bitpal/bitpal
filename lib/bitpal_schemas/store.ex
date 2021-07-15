defmodule BitPalSchemas.Store do
  use TypedEctoSchema
  alias BitPalSchemas.AccessToken

  @type id :: integer

  typed_schema "stores" do
    field(:label, :string) :: id

    has_many(:access_tokens, AccessToken)
  end
end
