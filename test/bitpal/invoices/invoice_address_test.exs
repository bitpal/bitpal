defmodule BitPal.InvoiceAddressTest do
  use BitPal.DataCase, async: true
  alias BitPal.Invoices
  alias BitPalSchemas.Address

  setup _tags do
    %{invoice: create_invoice(%{unique_currency: true, status: :draft})}
  end

  describe "assign_address/2" do
    test "address assigning", %{invoice: invoice} do
      assert address =
               create_address(
                 currency_id: invoice.payment_currency_id,
                 store_id: invoice.store_id
               )

      assert {:ok, invoice} = Invoices.assign_address(invoice, address)
      assert invoice.address == address

      assert {:error, _} =
               Invoices.assign_address(invoice, %Address{
                 id: "not-in-db",
                 address_index: 1,
                 currency_id: invoice.payment_currency_id
               })
    end
  end

  describe "ensure_address/2" do
    test "ensuring addresses", %{invoice: invoice} do
      create_address_key(invoice)

      assert {:ok, one = %{address_id: "one"}} =
               Invoices.ensure_address(invoice, fn key ->
                 {:ok, %{address_id: "one", address_index: Addresses.next_address_index(key)}}
               end)

      assert {:ok, ^one} =
               Invoices.ensure_address(one, fn key ->
                 {:ok, %{address_id: "xxx", address_index: Addresses.next_address_index(key)}}
               end)

      assert {:error, _} =
               Invoices.ensure_address(invoice, fn key ->
                 {:ok, %{address_id: "one", address_index: Addresses.next_address_index(key)}}
               end)

      assert {:ok, %{address_id: "two"}} =
               Invoices.ensure_address(invoice, fn key ->
                 {:ok, %{address_id: "two", address_index: Addresses.next_address_index(key)}}
               end)

      {:ok, address_key} = Invoices.address_key(invoice)
      ind = Addresses.next_address_index(address_key)

      create_invoice(payment_currency_id: invoice.payment_currency_id)

      assert {:ok, %{address_id: "three"}} =
               Invoices.ensure_address(invoice, fn key ->
                 {:ok, %{address_id: "three", address_index: Addresses.next_address_index(key)}}
               end)

      assert Addresses.next_address_index(address_key) != ind
    end
  end
end
