defmodule BitPalFactory.SettingsFactory do
  import BitPalFactory.FactoryHelpers
  alias BitPal.Currencies
  alias BitPalFactory.CurrencyFactory
  alias BitPalFactory.StoreFactory
  alias BitPalSchemas.AddressKey
  alias BitPalSchemas.Currency
  alias BitPalSchemas.Invoice
  alias BitPalSchemas.Store
  alias BitPalSettings.StoreSettings
  alias BitPal.Crypto.Base58

  @spec store_settings_update_params(keyword | map) :: map
  def store_settings_update_params(params \\ %{}) do
    Enum.into(
      params,
      %{
        "required_confirmations" => Faker.random_between(0, 100),
        "double_spend_timeout" => Faker.random_between(1, 1_000_000),
        "address_key" => unique_address_key_xpub()
      }
    )
  end

  @spec unique_address_key_xpub :: %{xpub: String.t()}
  def unique_address_key_xpub do
    %{xpub: sequence("xpub:test")}
  end

  @spec unique_address_key_viewkey :: %{
          viewkey: String.t(),
          address: String.t(),
          account: non_neg_integer
        }
  def unique_address_key_viewkey do
    %{
      viewkey: sequence("test_viewkey"),
      address: sequence("test_address_key_address"),
      account: 0
    }
  end

  def unique_address_key_data(currency_id) do
    if Currencies.has_xpub?(currency_id) do
      unique_address_key_xpub()
    else
      unique_address_key_viewkey()
    end
  end

  @spec create_address_key(Invoice.t() | map | keyword) :: AddressKey.t()
  def create_address_key(attrs \\ %{})

  def create_address_key(invoice = %Invoice{}) do
    create_address_key(store_id: invoice.store_id, currency_id: invoice.payment_currency_id)
  end

  def create_address_key(attrs) do
    attrs = Enum.into(attrs, %{})

    store_id = StoreFactory.get_or_create_store_id(attrs)
    currency_id = CurrencyFactory.get_or_create_currency_id(attrs)

    data = address_key_data(attrs, currency_id)

    {:ok, address_key} = StoreSettings.set_address_key(store_id, currency_id, data)
    address_key
  end

  defp address_key_data(%{data: data}, _), do: data
  defp address_key_data(%{xpub: xpub}, _), do: %{xpub: xpub}
  defp address_key_data(_, currency_id), do: unique_address_key_data(currency_id)

  @spec with_address_key(Store.t()) :: Store.t()
  def with_address_key(store, opts \\ %{}) do
    _address_key = create_address_key(Enum.into(opts, %{store: store}))
    store
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
        data =
          attrs[:data] ||
            unique_address_key_data(currency_id)

        {:ok, address_key} = StoreSettings.set_address_key(store_id, currency_id, data)

        address_key
    end
  end

  @spec get_or_create_address_key(map) :: AddressKey.t()
  def get_or_create_address_key(%{address_key: address_key}) do
    address_key
  end

  def get_or_create_address_key(%{store_id: store_id, payment_currency_id: currency_id}) do
    get_or_create_address_key(store_id, currency_id)
  end

  def get_or_create_address_key(%{store_id: store_id, currency_id: currency_id}) do
    get_or_create_address_key(store_id, currency_id)
  end

  def get_or_create_address_key(%{invoice: invoice}) do
    get_or_create_address_key(invoice.store_id, invoice.payment_currency_id)
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
