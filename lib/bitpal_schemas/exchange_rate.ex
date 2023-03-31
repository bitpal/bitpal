defmodule BitPalSchemas.ExchangeRate do
  use TypedEctoSchema
  alias BitPal.Currency
  alias BitPal.Currencies

  @type pair :: {Currency.id(), Currency.id()}

  typed_schema "exchange_rates" do
    field(:rate, :decimal)
    field(:base, Ecto.Atom)
    field(:quote, Ecto.Atom)

    field(:source, Ecto.Atom)
    field(:prio, :integer) :: non_neg_integer

    timestamps(inserted_at: false)
  end
end
