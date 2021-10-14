defmodule BitPalSchemas.UserToken do
  use TypedEctoSchema
  alias BitPalSchemas.User

  @type id :: integer

  schema "users_tokens" do
    field(:token, :binary)
    field(:context, :string)
    field(:sent_to, :string)
    belongs_to(:user, User)

    timestamps(updated_at: false)
  end
end
