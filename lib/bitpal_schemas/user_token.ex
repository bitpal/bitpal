defmodule BitPalSchemas.UserToken do
  use TypedEctoSchema
  alias BitPalSchemas.User

  @timestamps_opts [type: :utc_datetime]

  @type id :: integer

  typed_schema "users_tokens" do
    field(:token, :binary)
    field(:context, :string)
    field(:sent_to, :string)
    belongs_to(:user, User)

    timestamps(updated_at: false)
  end
end
