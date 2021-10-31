defmodule BitPalFixtures.AddressFixtures do
  alias BitPalSettings.StoreSettings
  alias BitPal.BCH.Cashaddress
  alias BitPal.Addresses

  @spec unique_address_id(Store.id(), Currency.id()) :: String.t()
  def unique_address_id(store_id, currency_id) do
    xpub = StoreSettings.get_xpub(store_id, currency_id)
    {:ok, address} = Addresses.register_with(currency_id, address_generator(xpub, currency_id))
    address.id
  end

  defp address_generator(xpub, :BCH) when is_binary(xpub) do
    fn address_index ->
      Cashaddress.derive_address(xpub, address_index)
    end
  end

  defp address_generator(_, _) do
    fn _index ->
      "address:#{Faker.UUID.v4()}"
    end
  end
end
