defmodule BitPalFactory.StoreFactory do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `BitPal.Stores` context.
  """

  import BitPalFactory.FactoryHelpers
  import Ecto.Changeset
  alias BitPal.Repo
  alias BitPal.Stores
  alias BitPalFactory.AuthFactory
  alias BitPalFactory.CurrencyFactory
  alias BitPalFactory.InvoiceFactory
  alias BitPalFactory.TransactionFactory
  alias BitPalSchemas.Store
  alias BitPalSchemas.User

  def unique_store_label do
    pretty_sequence(Faker.Company.name())
  end

  def valid_store_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      label: unique_store_label()
    })
  end

  @spec create_store :: Store.t()
  def create_store do
    {:ok, store} = Stores.create(valid_store_attributes(%{}))
    store
  end

  @spec create_store(map) :: Store.t()
  def create_store(attrs) when is_list(attrs) or (is_map(attrs) and not is_struct(attrs)) do
    if user = attrs[:user] do
      create_store(user, attrs)
    else
      {:ok, store} = Stores.create(valid_store_attributes(attrs))
      store
    end
  end

  @spec create_store(User.t(), map | keyword) :: Store.t()
  def create_store(user = %User{}, attrs \\ %{}) do
    {:ok, store} =
      user
      |> Stores.create(valid_store_attributes(attrs))

    store
  end

  @spec get_or_create_store(map) :: Store.t()
  def get_or_create_store(%{store_id: store_id}), do: Stores.fetch!(store_id)
  def get_or_create_store(%{store: store}), do: store
  def get_or_create_store(attrs), do: create_store(attrs)

  @spec get_or_create_store_id(map) :: Store.id()
  def get_or_create_store_id(%{store_id: store_id}), do: store_id
  def get_or_create_store_id(%{store: store}), do: store.id
  def get_or_create_store_id(attrs), do: create_store(attrs).id

  @spec with_token(Store.t(), map | keyword) :: Store.t()
  def with_token(store, attrs \\ %{}) do
    token = AuthFactory.create_token(store, attrs)

    if last_accessed = attrs[:last_accessed] do
      change(token, last_accessed: last_accessed |> NaiveDateTime.truncate(:second))
      |> Repo.update!()
    end

    store
    |> Repo.preload(:access_tokens, force: true)
  end

  @spec with_invoice(Store.t(), map | keyword) :: Store.t()
  def with_invoice(store, params \\ %{}) do
    with_invoices(store, Enum.into(params, %{invoice_count: 1}))
  end

  @spec with_invoices(Store.t(), map | keyword) :: Store.t()
  def with_invoices(store, params \\ %{}) do
    params = Enum.into(params, %{})
    currency_id = pick_currency_id(params)
    invoice_count = params[:invoice_count] || Faker.random_between(1, 3)
    generate_txs = params[:txs] == :auto

    invoices =
      Stream.repeatedly(fn ->
        invoice = InvoiceFactory.create_invoice(store, Map.put(params, :currency_id, currency_id))

        if generate_txs do
          TransactionFactory.with_txs(invoice)
        else
          invoice
        end
      end)
      |> Enum.take(invoice_count)

    %{store | invoices: invoices}
  end

  defp pick_currency_id(%{currencies: currencies}) do
    Enum.random(currencies)
  end

  defp pick_currency_id(%{currency_id: currency_id}) do
    currency_id
  end

  defp pick_currency_id(_) do
    CurrencyFactory.unique_currency_id()
  end
end
