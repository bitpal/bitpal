defmodule BitPalSchemas.AccessToken do
  use TypedEctoSchema
  alias BitPalSchemas.Store

  @timestamps_opts [type: :utc_datetime]

  @type id :: integer

  typed_schema "access_tokens" do
    field(:data, :string)
    field(:label, :string)

    field(:valid_until, :utc_datetime) :: DateTime.t() | nil
    field(:last_accessed, :utc_datetime) :: DateTime.t() | nil
    timestamps(updated_at: false, inserted_at: :created_at)

    belongs_to(:store, Store)
  end
end
