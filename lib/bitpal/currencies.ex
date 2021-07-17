defmodule BitPal.Currencies do
  import Ecto.Query
  alias BitPal.Repo
  alias BitPalSchemas.Address
  alias BitPalSchemas.Currency
  alias BitPalSchemas.Invoice
  alias Ecto.Changeset

  @currencies %{
    BCH: %{name: "Bitcoin Cash", exponent: 8, symbol: "BCH"},
    BTC: %{name: "Bitcoin", exponent: 8, symbol: "BTC"},
    DGC: %{name: "Dogecoin", exponent: 8, symbol: "DGC"},
    XMR: %{name: "Monero", exponent: 12, symbol: "XMR"}
  }

  @type height :: non_neg_integer()

  @spec fetch(Currency.id()) :: {:ok, Currency.t()} | :error
  def fetch(id) do
    case Repo.get(Currency, id) do
      nil -> :error
      currency -> {:ok, currency}
    end
  end

  @spec get!(Currency.id()) :: Currency.t()
  def get!(id) do
    Repo.get!(Currency, id)
  end

  def addresses(id, store_id) do
    from(a in Address,
      where: a.currency_id == ^id,
      left_join: i in Invoice,
      on: a.id == i.address_id,
      where: i.store_id == ^store_id
    )
    |> Repo.all()
  end

  def invoices(id, store_id) do
    from(i in Invoice, where: i.currency_id == ^id and i.store_id == ^store_id) |> Repo.all()
  end

  @spec register!([Currency.id()] | Currency.id()) :: :ok
  def register!(ids) when is_list(ids) do
    Enum.each(ids, &register!/1)
  end

  def register!(id) do
    Repo.insert!(%Currency{id: id}, on_conflict: :nothing)
  end

  @spec set_height!(Currency.id(), height) :: :ok
  def set_height!(id, height) do
    Repo.update!(Changeset.change(%Currency{id: id}, block_height: height))
  end

  @spec fetch_height!(Currency.id()) :: height
  def fetch_height!(id) do
    from(c in Currency, where: c.id == ^id, select: c.block_height)
    |> Repo.one!()
  end

  @spec fetch_height(Currency.id()) :: {:ok, height} | :error
  def fetch_height(id) do
    {:ok, fetch_height!(id)}
  rescue
    _ -> :error
  end

  @spec cast(atom | String.t()) :: {:ok, Currency.id()} | :error
  def cast(id) do
    {:ok, Money.Currency.to_atom(id)}
  catch
    _ -> :error
  end

  def configure_money do
    # Configure here because we want to configure :money, even when run as a library.
    # Should probably merge with existing config...
    Application.put_env(:money, :custom_currencies, @currencies)
  end
end
