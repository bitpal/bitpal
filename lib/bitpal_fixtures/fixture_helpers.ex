defmodule BitPalFixtures.FixtureHelpers do
  use BitPalFixtures
  alias BitPal.Accounts
  alias BitPal.Stores
  alias BitPalSettings.StoreSettings
  alias BitPalSchemas.Invoice
  alias BitPalSchemas.AddressKey

  @spec get_or_create_user(map) :: User.t()
  def get_or_create_user(%{user: user}), do: user
  def get_or_create_user(%{user_id: user_id}), do: Accounts.get_user!(user_id)
  def get_or_create_user(_), do: insert(:user)

  @spec get_or_create_store(map) :: Store.id()
  def get_or_create_store(%{store_id: store_id}), do: Stores.fetch!(store_id)
  def get_or_create_store(%{store: store}), do: store
  def get_or_create_store(_), do: insert(:store)

  @spec get_or_create_store_id(map) :: Store.id()
  def get_or_create_store_id(%{store_id: store_id}), do: store_id
  def get_or_create_store_id(%{store: store}), do: store.id
  def get_or_create_store_id(_), do: insert(:store).id

  @spec get_or_create_currency_id(map) :: Currency.id()
  def get_or_create_currency_id(%{currency_id: currency_id}), do: currency_id

  def get_or_create_currency_id(%{currency: currency_id}) when is_atom(currency_id) do
    currency_id
  end

  def get_or_create_currency_id(_), do: CurrencyFixtures.unique_currency_id()

  @spec get_or_create_invoice(map) :: Invoice.t()
  def get_or_create_invoice(%{invoice: invoice}), do: invoice
  def get_or_create_invoice(attrs), do: InvoiceFixtures.invoice_fixture(attrs)

  @spec get_or_create_address_key(map) :: AddressKey.t()
  def get_or_create_address_key(%{address_key: address_key}) do
    address_key
  end

  def get_or_create_address_key(%{store_id: store_id, currency_id: currency_id}) do
    address_key(store_id, currency_id)
  end

  def get_or_create_address_key(%{invoice: invoice}) do
    address_key(invoice.store_id, invoice.currency_id)
  end

  def get_or_create_address_key(params) do
    SettingsFixtures.address_key_fixture(params)
  end

  defp address_key(store_id, currency_id) do
    case StoreSettings.fetch_address_key(store_id, currency_id) do
      {:ok, address_key} -> address_key
      _ -> SettingsFixtures.address_key_fixture(%{store_id: store_id, currency_id: currency_id})
    end
  end
end
