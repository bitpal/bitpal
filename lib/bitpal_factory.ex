defmodule BitPalFactory do
  use ExMachina.Ecto, repo: BitPal.Repo

  alias BitPalSchemas.User
  alias BitPalSchemas.Store
  alias BitPalSchemas.Invoice
  alias BitPal.Accounts.Users
  alias BitPal.Stores

  import BitPalFactory.Accounts
  import BitPalFactory.Stores
  import BitPalFactory.Utils
  import BitPalFactory.Currencies

  defmacro __using__(_opts) do
    quote do
      import BitPalFactory
      import BitPalFactory.Accounts
      import BitPalFactory.Auth
      import BitPalFactory.Currencies
      import BitPalFactory.Stores
      import BitPalFactory.Invoices
    end
  end

  def user_factory(attrs) do
    attrs = valid_user_attributes(attrs)

    %User{}
    |> Users.registration_changeset(attrs)
    |> Ecto.Changeset.apply_changes()
  end

  def store_factory do
    label = sequence(:store, &"#{Faker.Company.name()} #{&1}")
    slug = Stores.slugified_label(label)

    %Store{
      label: label,
      slug: slug
    }
  end

  def invoice_factory(attrs) do
    store_id = get_or_insert_store(attrs)
    currency_id = get_or_create_currency_id(attrs)
    amount = into_money(attrs[:amount], currency_id)
    fiat_amount = into_money(attrs[:fiat_amount], attrs[:fiat_currency] || unique_fiat())

    pos_data =
      if :rand.uniform() > 0.25 do
        %{"ref" => Faker.Random.Elixir.random_between(0, 1_000_000)}
      else
        nil
      end

    %Invoice{
      store_id: store_id,
      amount: amount,
      fiat_amount: fiat_amount,
      currency_id: currency_id,
      description: Faker.Commerce.product_name(),
      email: Faker.Internet.email(),
      pos_data: pos_data
    }
  end

  def money_factory(attrs) do
    currency = attrs[:currency] || Faker.Util.pick([:USD, :EUR, :SEK])
    exponent = Money.Currency.exponent(currency) || 2
    amount = attrs[:amount] || Faker.random_between(0, 100 * floor(:math.pow(10, exponent)))

    %Money{
      amount: amount,
      currency: currency
    }
  end
end
