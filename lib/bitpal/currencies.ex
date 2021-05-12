defmodule BitPal.Currencies do
  import Ecto.Query, only: [from: 2]
  # import Config, only: [config: 3]
  alias BitPal.Repo
  alias BitPalSchemas.Currency

  @currencies %{
    BCH: %{name: "Bitcoin Cash", exponent: 8, symbol: "BCH"},
    BTC: %{name: "Bitcoin", exponent: 8, symbol: "BTC"},
    DGC: %{name: "Dogecoin", exponent: 8, symbol: "DGC"},
    XMR: %{name: "Monero", exponent: 12, symbol: "XMR"}
  }

  @type id :: atom | String.t()

  @spec get(id) :: Currency.t()
  def get(id) do
    Repo.one(from(c in Currency, where: c.id == ^normalize(id)))
  end

  @spec register!([Currency.id()]) :: :ok
  def register!(ids) when is_list(ids) do
    Enum.each(ids, &register!/1)
  end

  @spec register!(Currency.id()) :: :ok
  def register!(id) do
    Repo.insert!(%Currency{id: normalize(id)}, on_conflict: :nothing)
  end

  @spec normalize(atom | String.t()) :: String.t()
  def normalize(id) when is_binary(id) do
    id |> String.upcase()
  end

  def normalize(id) when is_atom(id) do
    Atom.to_string(id) |> String.upcase()
  end

  def configure_money do
    # Configure here because we want to configure :money, even when run as a library.
    # Should probably merge with existing config...
    Application.put_env(:money, :custom_currencies, @currencies)
  end
end
