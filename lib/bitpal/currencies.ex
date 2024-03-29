defmodule BitPal.Currencies do
  import Ecto.Query
  alias BitPal.Repo
  alias BitPalSchemas.Address
  alias BitPalSchemas.Currency
  alias BitPalSchemas.Invoice
  alias BitPalSchemas.Store
  require Logger

  @type height :: non_neg_integer()

  @spec supported_currencies :: [Currency.id()]
  def supported_currencies do
    Application.get_env(:money, :custom_currencies)
    |> Map.keys()
  end

  @spec is_crypto(atom) :: boolean
  def is_crypto(id) do
    Application.get_env(:money, :custom_currencies) |> Map.has_key?(id) &&
      !(Atom.to_string(id) |> String.starts_with?("𝓕 "))
  end

  @spec add_custom_curreny(atom, map) :: :ok
  def add_custom_curreny(id, opts) do
    currencies =
      Application.get_env(:money, :custom_currencies)
      |> Map.put_new(id, opts)

    Application.put_env(:money, :custom_currencies, currencies)
  end

  @spec fetch(Currency.id()) :: {:ok, Currency.t()} | :error
  def fetch(id) do
    case Repo.get(Currency, id) do
      nil -> :error
      currency -> {:ok, currency}
    end
  end

  @spec get!(Currency.id()) :: Currency.t()
  def get!(id), do: Repo.get!(Currency, id)

  @spec all :: [Currency.t()]
  def all, do: Repo.all(Currency)

  @spec addresses(Currency.id(), Store.id()) :: [Address.t()]
  def addresses(id, store_id) do
    from(a in Address,
      where: a.currency_id == ^id,
      left_join: i in Invoice,
      on: a.id == i.address_id,
      where: i.store_id == ^store_id
    )
    |> Repo.all()
  end

  def invoice_ids(ids) when is_list(ids) do
    from(i in Invoice, where: i.payment_currency_id in ^ids, select: i.id) |> Repo.all()
  end

  @spec invoices(Currency.id(), Store.id()) :: [Invoice.t()]
  def invoices(id, store_id) do
    from(i in Invoice, where: i.payment_currency_id == ^id and i.store_id == ^store_id)
    |> Repo.all()
  end

  @spec ensure_exists!([Currency.id()]) :: :ok
  def ensure_exists!(ids) when is_list(ids) do
    Enum.each(ids, &ensure_exists!/1)
  end

  @spec ensure_exists!(Currency.id()) :: :ok
  def ensure_exists!(id) when is_atom(id) do
    Repo.insert!(%Currency{id: id}, on_conflict: :nothing)
  end

  @spec cast(atom | String.t()) :: {:ok, Currency.id()} | :error
  def cast(id) do
    currency = Money.Currency.to_atom(id)

    if currency do
      {:ok, currency}
    else
      :error
    end
  rescue
    _ -> :error
  end

  def valid_address_key?(currency_id, %{xpub: "xpub" <> _rest}) do
    has_xpub?(currency_id)
  end

  def valid_address_key?(currency_id, %{xpub: _xpub}) do
    is_test_currency?(currency_id)
  end

  def valid_address_key?(:XMR, %{viewkey: _viewkey}) do
    true
  end

  def valid_address_key?(currency_id, %{viewkey: _viewkey}) do
    is_test_currency?(currency_id)
  end

  def valid_address_key?(_currency_id, _key) do
    false
  end

  def has_xpub?(:XMR), do: false
  def has_xpub?(_), do: true

  def is_test_currency?(currency_id) do
    case Money.Currency.name!(currency_id) do
      "Testcrypto " <> _ -> true
      _ -> false
    end
  end
end
