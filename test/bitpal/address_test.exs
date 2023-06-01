defmodule BitPal.AddressTest do
  use BitPal.DataCase, async: true
  alias BitPal.Addresses
  alias BitPal.Invoices

  setup _tags do
    currency_id = unique_currency_id()
    store = create_store()
    address_key = create_address_key(store: store, currency_id: currency_id)
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
        create_address_key(
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
        create_address_key(
          store: create_store(),
          currency_id: address_key.currency_id
        )

      assert {:ok, _} = Addresses.register(other_address_key, unique_address_id(), 0)
    end
  end

  describe "generate_address/2" do
    defp key_data_id(%{xpub: xpub}), do: xpub
    defp key_data_id(%{viewkey: viewkey}), do: viewkey

    defp test_address_generator(key) do
      i = Addresses.next_address_index(key)
      {:ok, %{address_id: "#{key_data_id(key.data)}-#{i}-#{key.currency_id}", address_index: i}}
    end

    test "generates", %{address_key: address_key} do
      for i <- 0..3 do
        {:ok, address} = Addresses.generate_address(address_key, &test_address_generator/1)

        assert address.address_index == i
        # Tests the compound of indata to the generator
        assert "#{key_data_id(address_key.data)}-#{i}-#{address_key.currency_id}" == address.id
      end
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
        create_invoice(payment_currency_id: currency_id, address_id: :auto, status: :draft).address_id

      open_address =
        create_invoice(
          payment_currency_id: currency_id,
          address_id: :auto,
          status: :open
        ).address_id

      processing_address =
        create_invoice(
          payment_currency_id: currency_id,
          address_id: :auto,
          status: :processing
        ).address_id

      %{
        currency_id: currency_id,
        draft_address: draft_address,
        open_address: open_address,
        processing_address: processing_address
      }
    end

    test "all_open_ids/1", %{
      currency_id: currency_id,
      open_address: open_address
    } do
      assert [open_address] == Addresses.all_open_ids(currency_id)
    end

    test "all_active_ids/1", %{
      currency_id: currency_id,
      open_address: open_address,
      processing_address: processing_address
    } do
      assert Enum.sort([open_address, processing_address]) ==
               Enum.sort(Addresses.all_active_ids(currency_id))
    end

    test "all_active/1", %{
      currency_id: currency_id,
      open_address: open_address,
      processing_address: processing_address
    } do
      assert Enum.sort([open_address, processing_address]) ==
               Addresses.all_active(currency_id)
               |> Enum.map(fn a -> a.id end)
               |> Enum.sort()
    end
  end

  defp assign_address(address) do
    invoice = create_invoice(status: :draft)
    assert {:ok, _} = Invoices.assign_address(invoice, address)
  end
end
