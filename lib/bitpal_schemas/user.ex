defmodule BitPalSchemas.User do
  use TypedEctoSchema
  alias BitPalSchemas.Store

  @type id :: integer

  typed_schema "users" do
    field(:email, :string)
    field(:password, :string, virtual: true, redact: true)
    field(:hashed_password, :string, redact: true)
    field(:confirmed_at, :naive_datetime)

    many_to_many(:stores, Store, join_through: "users_stores")

    timestamps()
  end
end
