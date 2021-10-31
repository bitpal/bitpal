defmodule BitPalFixtures.SettingsFixtures do
  import BitPalFixtures.FixtureHelpers
  alias BitPalSettings.StoreSettings
  alias BitPalSchemas.Invoice

  @spec unique_address_key_id :: String.t()
  def unique_address_key_id, do: "testkey:#{System.unique_integer()}"

  @spec address_key_fixture(Invoice.t() | map | keyword) :: AddressKey.t()
  def address_key_fixture(attrs \\ %{})

  def address_key_fixture(invoice = %Invoice{}) do
    address_key_fixture(store_id: invoice.store_id, currency_id: invoice.currency_id)
  end

  def address_key_fixture(attrs) do
    attrs = Enum.into(attrs, %{})

    store_id = get_or_create_store_id(attrs)
    currency_id = get_or_create_currency_id(attrs)
    data = attrs[:data] || unique_address_key_id()

    {:ok, address_key} = StoreSettings.set_address_key(store_id, currency_id, data)
    address_key
  end

  @spec ensure_address_key!(map | keyword) :: AddressKey.t()
  def ensure_address_key!(attrs) do
    attrs = Enum.into(attrs, %{})

    store_id = get_or_create_store_id(attrs)
    currency_id = get_or_create_currency_id(attrs)

    case StoreSettings.fetch_address_key(store_id, currency_id) do
      {:ok, address_key} ->
        address_key

      _ ->
        data = attrs[:data] || unique_address_key_id()
        {:ok, address_key} = StoreSettings.set_address_key(store_id, currency_id, data)
        address_key
    end
  end
end
