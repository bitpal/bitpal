defmodule AddressTest do
  use BitPal.IntegrationCase, async: true
  import BitPalFixtures.AddressFixtures, only: [unique_address_id: 0]
  alias BitPal.Addresses
  alias BitPal.Invoices

  setup tags do
    currency_id = Map.fetch!(tags, :currency_id)
    store = insert(:store)
    address_key = SettingsFixtures.address_key_fixture(store: store, currency_id: currency_id)
    %{store: store, address_key: address_key, currency_id: currency_id}
  end

  describe "register/3" do
    test "address registration", %{address_key: address_key} do
      assert {:ok, _} = Addresses.register(address_key, unique_address_id(), 0)
      assert {:ok, _} = Addresses.register(address_key, unique_address_id(), 1)
      assert {:ok, _} = Addresses.register(address_key, unique_address_id(), 2)
    end

    test "cannot reuse addresses", %{address_key: address_key} do
      address = unique_address_id()
      assert {:ok, _} = Addresses.register(address_key, address, 0)
      assert {:error, changeset} = Addresses.register(address_key, address, 1)
      assert "has already been taken" in errors_on(changeset).id
    end

    test "cannot reuse indexes", %{address_key: address_key} do
      assert {:ok, _} = Addresses.register(address_key, unique_address_id(), 0)
      assert {:error, changeset} = Addresses.register(address_key, unique_address_id(), 0)
      assert "has already been taken" in errors_on(changeset).address_index
    end

    test "it's fine to have the same index for separate currencies", %{
      store: store,
      address_key: address_key
    } do
      assert {:ok, _} = Addresses.register(address_key, unique_address_id(), 0)

      other_address_key =
        SettingsFixtures.address_key_fixture(
          store: store,
          currency_id: unique_currency_id()
        )

      assert {:ok, _} = Addresses.register(other_address_key, unique_address_id(), 0)
    end

    test "it's fine to have the same index for separate stores", %{
      address_key: address_key
    } do
      assert {:ok, _} = Addresses.register(address_key, unique_address_id(), 0)

      other_address_key =
        SettingsFixtures.address_key_fixture(
          store: insert(:store),
          currency_id: address_key.currency_id
        )

      assert {:ok, _} = Addresses.register(other_address_key, unique_address_id(), 0)
    end
  end

  describe "generate_address/2" do
    test "generates", %{address_key: address_key} do
      data = address_key.data

      for i <- 0..3 do
        {:ok, address} = Addresses.generate_address(address_key, &test_address_generator/1)
        # Tests the compound of indata to the generator
        assert "#{data}-#{i}-#{address_key.currency_id}" == address.id
      end
    end

    test "generate multiple addresses", %{address_key: address_key} do
      addresses = Addresses.generate_addresses!(address_key, &test_address_generator/1, 5)

      assert length(addresses) == 5
      assert Addresses.next_address_index(address_key) == 5
    end
  end

  describe "next_address_index/1" do
    test "next address", %{address_key: address_key} do
      assert Addresses.next_address_index(address_key) == 0
      assert {:ok, _} = Addresses.register(address_key, unique_address_id(), 0)
      assert {:ok, _} = Addresses.register(address_key, unique_address_id(), 1)
      assert Addresses.next_address_index(address_key) == 2
    end
  end

  describe "find_unused_address/1" do
    test "unused address", %{address_key: address_key} do
      assert {:ok, _} = Addresses.register(address_key, unique_address_id(), 0)
      assert {:ok, _} = Addresses.register(address_key, unique_address_id(), 1)

      a1 = Addresses.find_unused_address(address_key)
      assert a1 != nil

      assign_address(a1)
      a2 = Addresses.find_unused_address(address_key)
      assert a2 != nil
      assert a2 != a1

      assign_address(a2)
      assert Addresses.find_unused_address(address_key) == nil
    end
  end

  describe "addresses with invoice statuses" do
    setup %{currency_id: currency_id} do
      draft_address =
        InvoiceFixtures.invoice_fixture(currency_id: currency_id, address: :auto).address_id

      open_address =
        InvoiceFixtures.invoice_fixture(
          currency_id: currency_id,
          address: :auto,
          status: :open
        ).address_id

      processing_address =
        InvoiceFixtures.invoice_fixture(
          currency_id: currency_id,
          address: :auto,
          status: :processing
        ).address_id

      %{
        currency_id: currency_id,
        draft_address: draft_address,
        open_address: open_address,
        processing_address: processing_address
      }
    end

    test "all_open/1", %{
      currency_id: currency_id,
      open_address: open_address
    } do
      assert [open_address] == Addresses.all_open(currency_id)
    end

    test "all_active/1", %{
      currency_id: currency_id,
      open_address: open_address,
      processing_address: processing_address
    } do
      assert Enum.sort([open_address, processing_address]) ==
               Enum.sort(Addresses.all_active(currency_id))
    end
  end

  defp test_address_generator(%{key: key, index: i, currency_id: currency_id}) do
    "#{key}-#{i}-#{currency_id}"
  end

  defp assign_address(address) do
    invoice = InvoiceFixtures.invoice_fixture()
    assert {:ok, _} = Invoices.assign_address(invoice, address)
  end
end
