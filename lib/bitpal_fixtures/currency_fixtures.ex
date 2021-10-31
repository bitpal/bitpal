defmodule BitPalFixtures.CurrencyFixtures do
  alias BitPal.Currencies

  @spec seed_supported_currencies :: :ok
  def seed_supported_currencies do
    Currencies.ensure_exists!(Currencies.supported_currencies())
  end

  @spec currency_id :: atom
  def currency_id do
    Faker.Util.pick(Currencies.supported_currencies())
    |> currency_id()
  end

  @spec currency_id(Currency.id()) :: atom
  def currency_id(id) when is_atom(id) do
    Currencies.ensure_exists!(id)
    id
  end

  @spec currency_id_s :: String.t()
  def currency_id_s do
    currency_id()
    |> Atom.to_string()
  end

  @spec currency_id_s(Currency.id()) :: String.t()
  def currency_id_s(id) when is_atom(id) do
    currency_id(id)
    |> Atom.to_string()
  end

  @spec fiat_currency :: String.t()
  def fiat_currency do
    Faker.Util.pick(["USD", "EUR", "SEK"])
  end
end
