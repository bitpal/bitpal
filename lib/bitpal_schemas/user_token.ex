defmodule BitPalSchemas.UserToken do
  use Ecto.Schema
  alias BitPalSchemas.User

  schema "users_tokens" do
    field(:token, :binary)
    field(:context, :string)
    field(:sent_to, :string)
    belongs_to(:user, User)

    timestamps(updated_at: false)
  end
end
