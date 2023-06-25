defmodule BitPalSchemas.ExchangeRate do
  use TypedEctoSchema
  alias BitPalSchemas.Currency

  @timestamps_opts [type: :utc_datetime]

  @type pair :: {Currency.id(), Currency.id()}
  @type bundled :: %{Currency.t() => %{Currency.t() => t()}}

  typed_schema "exchange_rates" do
    field(:rate, :decimal)
    field(:base, Ecto.Atom)
    field(:quote, Ecto.Atom)

    field(:source, Ecto.Atom)
    field(:prio, :integer) :: non_neg_integer

    timestamps(inserted_at: false)
  end
end
