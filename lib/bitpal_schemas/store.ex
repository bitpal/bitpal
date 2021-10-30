defmodule BitPalSchemas.Store do
  use TypedEctoSchema
  alias BitPalSchemas.AccessToken
  alias BitPalSchemas.Invoice
  alias BitPalSchemas.User
  alias BitPalSchemas.CurrencySettings

  @type id :: integer

  @derive {Phoenix.Param, key: :slug}

  typed_schema "stores" do
    field(:label, :string)
    field(:slug, :string)

    many_to_many(:users, User, join_through: "users_stores")
    has_many(:invoices, Invoice, references: :id)
    has_many(:access_tokens, AccessToken)
    has_many(:currency_settings, CurrencySettings)
  end
end
