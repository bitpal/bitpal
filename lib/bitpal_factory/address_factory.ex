defmodule BitPalFactory.AddressFactory do
  alias BitPal.Addresses
  alias BitPal.BCH.Cashaddress
  alias BitPalFactory.InvoiceFactory
  alias BitPalFactory.SettingsFactory
  alias BitPalSchemas.Address
  alias BitPalSchemas.AddressKey
  alias BitPalSchemas.Invoice

  # Note that in the future we might generate addresses that look real.
  # This is good enough for now...
  @spec unique_address_id(atom | String.t()) :: String.t()
  def unique_address_id(prefix \\ "address")

  def unique_address_id(prefix) when is_atom(prefix) do
    unique_address_id(Atom.to_string(prefix))
  end

  def unique_address_id(prefix) when is_binary(prefix) do
    String.downcase(prefix) <> ":" <> Faker.UUID.v4()
  end

  @spec create_address :: Address.t()
  def create_address do
    InvoiceFactory.create_invoice()
    |> create_address()
  end

  @spec create_address(map | keyword) :: Address.t()
  def create_address(attrs) when not is_struct(attrs) do
    attrs = Enum.into(attrs, %{})

    address =
      SettingsFactory.get_or_create_address_key(attrs)
      |> create_address(attrs)

    if invoice = attrs[:invoice] do
      InvoiceFactory.assoc_address(invoice, address)
    end

    address
  end

  @spec create_address(Invoice.t() | AddressKey.t(), map | keyword) :: Address.t()
  def create_address(ref, attrs \\ %{})

  def create_address(invoice = %Invoice{}, attrs) do
    address =
      SettingsFactory.get_or_create_address_key(invoice)
      |> create_address(attrs)

    InvoiceFactory.assoc_address(invoice, address)
    address
  end

  def create_address(address_key = %AddressKey{}, attrs) do
    if address_id = attrs[:address_id] do
      {:ok, address} = Addresses.register_next_address(address_key, address_id)
      address
    else
      {:ok, address} = Addresses.generate_address(address_key, &generate_address/1)
      address
    end
  end

  @spec generate_address(AddressKey.t()) :: Addresses.address_generator_res()
  def generate_address(key = %AddressKey{data: data, currency_id: :BCH}) do
    index = Addresses.next_address_index(key)

    {:ok,
     %{
       address_id: Cashaddress.derive_address(data.xpub, index),
       address_index: index
     }}
  end

  def generate_address(key = %{currency_id: currency_id}) do
    {:ok,
     %{
       address_id: unique_address_id(currency_id),
       address_index: Addresses.next_address_index(key)
     }}
  end
end
