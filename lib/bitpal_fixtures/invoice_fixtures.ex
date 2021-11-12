defmodule BitPalFixtures.InvoiceFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `BitPal.Invoices` context.
  """

  import BitPalFixtures.FixtureHelpers
  alias BitPal.Addresses
  alias BitPal.Invoices
  alias BitPalSchemas.Store
  alias BitPalFixtures.AddressFixtures
  alias BitPalFixtures.SettingsFixtures
  alias BitPalApi.Authentication.BasicAuth
  alias BitPalFactory.Factory

  def rand_pos_float(max \\ 1.0), do: :rand.uniform() * max

  def valid_pos_data do
    %{"ref" => Faker.Random.Elixir.random_between(0, 1_000_000)}
  end

  defp add_pos_data(attrs = %{pos_data: _}) do
    attrs
  end

  defp add_pos_data(attrs) do
    if rand_pos_float() < 0.75 do
      Map.merge(%{pos_data: valid_pos_data()}, attrs)
    else
      attrs
    end
  end

  def valid_invoice_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      amount: rand_pos_float(),
      exchange_rate: rand_pos_float(),
      currency_id: Factory.unique_currency_id() |> Atom.to_string(),
      fiat_currency: Factory.unique_fiat(),
      description: Faker.Commerce.product_name(),
      email: Faker.Internet.email()
    })
    |> add_pos_data()
  end

  @spec invoice_fixture :: Invoice.t()
  def invoice_fixture do
    invoice_fixture(%{})
  end

  @spec invoice_fixture(map | keyword) :: Invoice.t()
  def invoice_fixture(attrs) when (is_map(attrs) and not is_struct(attrs)) or is_list(attrs) do
    attrs = valid_invoice_attributes(attrs)

    get_or_create_store_id(attrs)
    |> invoice_fixture(Map.drop(attrs, [:store, :store_id]))
  end

  @spec invoice_fixture(Store.t() | Store.id() | Plug.Conn.t(), map | keyword) :: Invoice.t()
  def invoice_fixture(store_ref, attrs \\ %{})

  def invoice_fixture(store = %Store{}, attrs) do
    invoice_fixture(store.id, attrs)
  end

  def invoice_fixture(store_id, attrs) when is_integer(store_id) do
    attrs = valid_invoice_attributes(attrs)

    {:ok, invoice} = Invoices.register(store_id, Map.drop(attrs, [:address, :status]))

    if address_key = attrs[:address_key] do
      SettingsFixtures.ensure_address_key!(
        store_id: store_id,
        currency_id: invoice.currency_id,
        data: address_key
      )
    end

    invoice
    |> assign_address(attrs)
    |> change_status(attrs)
  end

  def invoice_fixture(conn = %Plug.Conn{}, attrs) do
    {:ok, store_id} = BasicAuth.parse(conn)
    invoice_fixture(store_id, attrs)
  end

  @spec ensure_address(Invoice.t(), map | keyword) :: Invoice.t()
  def ensure_address(invoice, params \\ %{})

  def ensure_address(invoice = %{address_id: address_id}, _) when not is_nil(address_id) do
    invoice
  end

  def ensure_address(invoice, params) do
    assign_address(invoice, %{address: params[:address] || :auto})
  end

  defp assign_address(invoice, %{address: :auto}) do
    address = AddressFixtures.address_fixture(invoice)
    {:ok, invoice} = Invoices.assign_address(invoice, address)
    invoice
  end

  # FIXME address_id here
  defp assign_address(invoice, %{address: address_id}) when is_binary(address_id) do
    address_key = get_or_create_address_key(invoice)

    address =
      if address = Addresses.get(address_id) do
        address
      else
        {:ok, address} = Addresses.register_next_address(address_key, address_id)
        address
      end

    {:ok, invoice} = Invoices.assign_address(invoice, address)
    invoice
  end

  defp assign_address(invoice, _), do: invoice

  defp change_status(invoice, %{status: status}) do
    Invoices.set_status!(invoice, status)
  end

  defp change_status(invoice, _), do: invoice
end
