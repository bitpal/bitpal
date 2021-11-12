defmodule BitPalFactory.SettingsFactory do
  import BitPalFactory.FactoryHelpers
  alias BitPalFactory.StoreFactory
  alias BitPalFactory.CurrencyFactory
  alias BitPalSettings.StoreSettings
  alias BitPalSchemas.Invoice

  @spec unique_address_key_id :: String.t()
  def unique_address_key_id, do: sequence("testkey")

  @spec create_address_key(Invoice.t() | map | keyword) :: AddressKey.t()
  def create_address_key(attrs \\ %{})

  def create_address_key(invoice = %Invoice{}) do
    create_address_key(store_id: invoice.store_id, currency_id: invoice.currency_id)
  end

  def create_address_key(attrs) do
    attrs = Enum.into(attrs, %{})

    store_id = StoreFactory.get_or_create_store_id(attrs)
    currency_id = CurrencyFactory.get_or_create_currency_id(attrs)
    data = attrs[:data] || unique_address_key_id()

    {:ok, address_key} = StoreSettings.set_address_key(store_id, currency_id, data)
    address_key
  end

  @spec ensure_address_key!(map | keyword) :: AddressKey.t()
  def ensure_address_key!(attrs) do
    attrs = Enum.into(attrs, %{})

    store_id = StoreFactory.get_or_create_store_id(attrs)
    currency_id = CurrencyFactory.get_or_create_currency_id(attrs)

    case StoreSettings.fetch_address_key(store_id, currency_id) do
      {:ok, address_key} ->
        address_key

      _ ->
        data = attrs[:data] || unique_address_key_id()
        {:ok, address_key} = StoreSettings.set_address_key(store_id, currency_id, data)
        address_key
    end
  end

  @spec get_or_create_address_key(map) :: AddressKey.t()
  def get_or_create_address_key(%{address_key: address_key}) do
    address_key
  end

  def get_or_create_address_key(%{store_id: store_id, currency_id: currency_id}) do
    get_or_create_address_key(store_id, currency_id)
  end

  def get_or_create_address_key(%{invoice: invoice}) do
    get_or_create_address_key(invoice.store_id, invoice.currency_id)
  end

  def get_or_create_address_key(params) do
    create_address_key(params)
  end

  @spec get_or_create_address_key(Store.id(), Currency.id()) :: AddressKey.t()
  def get_or_create_address_key(store_id, currency_id) do
    case StoreSettings.fetch_address_key(store_id, currency_id) do
      {:ok, address_key} -> address_key
      _ -> create_address_key(%{store_id: store_id, currency_id: currency_id})
    end
  end
end
