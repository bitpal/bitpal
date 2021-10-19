defmodule BitPal.InvoicesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `BitPal.Invoices` context.
  """

  alias BitPal.Addresses
  alias BitPal.Invoices
  alias Ecto.UUID

  def unique_store_label, do: "Store#{System.unique_integer()}"

  @spec unique_address_id :: String.t()
  def unique_address_id, do: "address:#{UUID.generate()}"

  def valid_invoice_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      amount: 1.2,
      exchange_rate: 2.0,
      currency: "BCH",
      fiat_currency: "USD"
    })
  end

  def invoice_fixture(store_id, attrs \\ %{}) do
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
