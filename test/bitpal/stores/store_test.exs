defmodule BitPal.StoreTest do
  use BitPal.DataCase, async: true
  alias BitPal.Repo
  alias BitPal.Stores

  setup _tags do
    %{store: create_store() |> Repo.preload([:users])}
  end

  test "store invoice association", %{store: store} do
    assert {:ok, invoice} = Invoices.register(store.id, valid_invoice_attributes())

    store = Repo.preload(store, [:invoices])
    assert length(store.invoices) == 1
    assert invoice.store_id == store.id
  end

  describe "all_addresses/1" do
    test "get current and previous address_key addresses", %{store: store} do
      _key0 = create_address_key(store: store)

      i0 = store |> create_invoice(address: :auto, status: :open)
      i1 = store |> create_invoice(address: :auto, status: :open)

      key1 = create_address_key(store: store)

      a0 = key1 |> create_address()
      a1 = key1 |> create_address()

      address_ids =
        Stores.all_addresses(store.id)
        |> Stream.map(fn address -> address.id end)
        |> Enum.into(MapSet.new())

      assert MapSet.member?(address_ids, i0.address_id)
      assert MapSet.member?(address_ids, i1.address_id)
      assert MapSet.member?(address_ids, a0.id)
      assert MapSet.member?(address_ids, a1.id)
    end
  end
end
