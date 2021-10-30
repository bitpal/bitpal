defmodule BitPalFixtures.InvoiceFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `BitPal.Invoices` context.
  """

  alias BitPal.Addresses
  alias BitPal.Invoices
  alias BitPalSchemas.Store
  alias Ecto.UUID

  @spec unique_address_id :: String.t()
  def unique_address_id, do: "address:#{UUID.generate()}"

  def rand_pos_float(max \\ 1.0), do: :rand.uniform() * max

  def valid_pos_data do
    %{"ref" => Faker.Random.Elixir.random_between(0, 1_000_000)}
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
      currency: "BCH",
      fiat_currency: "USD",
      description: Faker.Commerce.product_name(),
      email: Faker.Internet.email()
    })
    |> add_pos_data()
  end

  def invoice_fixture(store_ref, attrs \\ %{})

  def invoice_fixture(store = %Store{}, attrs) do
    invoice_fixture(store.id, attrs)
  end

  def invoice_fixture(store_id, attrs) do
    attrs = valid_invoice_attributes(attrs)

    {:ok, invoice} = Invoices.register(store_id, Map.drop(attrs, [:address, :status]))

    invoice
    |> assign_address(attrs)
    |> change_status(attrs)
  end

  defp assign_address(invoice, %{address: :auto}) do
    assign_address(invoice, %{address: unique_address_id()})
  end

  defp assign_address(invoice, %{address: address_id}) when is_binary(address_id) do
    {:ok, address} = Addresses.register_next_address(invoice.currency_id, address_id)
    {:ok, invoice} = Invoices.assign_address(invoice, address)
    invoice
  end

  defp assign_address(invoice, _), do: invoice

  defp change_status(invoice, %{status: status}) do
    Invoices.set_status!(invoice, status)
  end

  defp change_status(invoice, _), do: invoice
end
