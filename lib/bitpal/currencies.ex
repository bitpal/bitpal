defmodule BitPal.Currencies do
  import Ecto.Query
  require Logger
  alias BitPal.Repo
  alias BitPalSchemas.Address
  alias BitPalSchemas.Currency
  alias BitPalSchemas.Invoice
  alias Ecto.Changeset

  @type height :: non_neg_integer()

  @spec supported_currencies :: [Currency.id()]
  def supported_currencies do
    Application.get_env(:money, :custom_currencies)
    |> Map.keys()
  end

  @spec is_crypto(atom) :: boolean
  def is_crypto(id) do
    Application.get_env(:money, :custom_currencies)
    |> Map.has_key?(id)
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

  @spec all() :: [Currency.t()]
  def all(), do: Repo.all(Currency)

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
    from(i in Invoice, where: i.currency_id in ^ids, select: i.id) |> Repo.all()
  end

  @spec invoices(Currency.id(), Store.id()) :: [Invoice.t()]
  def invoices(id, store_id) do
    from(i in Invoice, where: i.currency_id == ^id and i.store_id == ^store_id) |> Repo.all()
  end

  @spec ensure_exists!([Currency.id()]) :: :ok
  def ensure_exists!(ids) when is_list(ids) do
    Enum.each(ids, &ensure_exists!/1)
  end

  @spec ensure_exists!(Currency.id()) :: :ok
  def ensure_exists!(id) when is_atom(id) do
    Repo.insert!(%Currency{id: id}, on_conflict: :nothing)
  end

  @spec set_height!(Currency.id(), height) :: :ok
  def set_height!(id, height) do
    Repo.update!(Changeset.change(%Currency{id: id}, block_height: height))
  end

  @spec fetch_height!(Currency.id()) :: height | nil
  def fetch_height!(id) do
    from(c in Currency, where: c.id == ^id, select: c.block_height)
    |> Repo.one!()
  end

  @spec fetch_height(Currency.id()) :: {:ok, height} | :error
  def fetch_height(id) do
    case fetch_height!(id) do
      nil -> :error
      height -> {:ok, height}
    end
  rescue
    _ -> :error
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

  def valid_address_key?(currency_id, key) when is_binary(key) do
    cond do
      is_test_currency?(currency_id) ->
        key != ""

      has_xpub?(currency_id) ->
        case key do
          "xpub" <> _ -> true
          _ -> false
        end

      true ->
        Logger.error("Unknown address key format for: #{currency_id}")
        true
    end
  end

  def valid_address_key?(_, _), do: false

  def has_xpub?(:XMR), do: false
  def has_xpub?(_), do: true

  def is_test_currency?(currency_id) do
    case Money.Currency.name!(currency_id) do
      "Testcrypto " <> _ -> true
      _ -> false
    end
  end
end
