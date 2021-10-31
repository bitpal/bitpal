defmodule BitPalFixtures.AddressFixtures do
  import BitPalFixtures.FixtureHelpers
  alias BitPal.Addresses
  alias BitPal.Invoices
  alias BitPalSchemas.Address
  alias BitPalSchemas.AddressKey
  alias BitPalSchemas.Invoice
  alias BitPalFixtures.InvoiceFixtures

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

  @spec address_fixture :: Address.t()
  def address_fixture do
    InvoiceFixtures.invoice_fixture()
    |> address_fixture()
  end

  @spec address_fixture(map | keyword) :: Address.t()
  def address_fixture(attrs) when not is_struct(attrs) do
    attrs = Enum.into(attrs, %{})

    address =
      get_or_create_address_key(attrs)
      |> address_fixture(attrs)

    if invoice = attrs[:invoice] do
      {:ok, _} = Invoices.assign_address(invoice, address)
    end

    address
  end

  @spec address_fixture(Invoice.t() | AddressKey.t(), map | keyword) :: Address.t()
  def address_fixture(ref, attrs \\ %{})

  def address_fixture(invoice = %Invoice{}, attrs) do
    address =
      get_or_create_address_key(invoice)
      |> address_fixture(attrs)

    {:ok, _} = Invoices.assign_address(invoice, address)
    address
  end

  def address_fixture(address_key = %AddressKey{}, attrs) do
    if address_id = attrs[:address_id] do
      {:ok, address} = Addresses.register_next_address(address_key, address_id)
      address
    else
      {:ok, address} =
        Addresses.generate_address(address_key, fn _args ->
          unique_address_id(address_key.currency_id)
        end)

      address
    end
  end
end
