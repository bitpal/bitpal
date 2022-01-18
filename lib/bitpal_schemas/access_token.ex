defmodule BitPalSchemas.AccessToken do
  use TypedEctoSchema
  alias BitPalSchemas.Store

  @type id :: integer

  typed_schema "access_tokens" do
    field(:data, :string)
    field(:label, :string)

    field(:valid_until, :naive_datetime) :: NaiveDateTime.t() | nil
    field(:last_accessed, :naive_datetime) :: NaiveDateTime.t() | nil
    timestamps(updated_at: false, inserted_at: :created_at)

    belongs_to(:store, Store)
  end
end
