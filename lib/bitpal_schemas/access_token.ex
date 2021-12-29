defmodule BitPalSchemas.AccessToken do
  use TypedEctoSchema
  alias BitPalSchemas.Store

  @type id :: integer

  typed_schema "access_tokens" do
    # The token data also contains the signed time, so we don't have to track it explicitly.
    field(:data, :string)
    field(:label, :string)

    field(:valid_until, :naive_datetime) :: NaiveDateTime.t() | nil
    field(:last_accessed, :naive_datetime) :: NaiveDateTime.t() | nil

    belongs_to(:store, Store)
  end
end
