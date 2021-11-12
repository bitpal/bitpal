defmodule BitPalFactory.InvoiceFactoryTest do
  use BitPal.IntegrationCase, async: true
  alias BitPalSettings.StoreSettings
  alias BitPalSchemas.Address

  setup _tags do
    %{store: create_store()}
  end

  describe "create_invoice/2" do
    test "inserts into db", %{store: store} do
      invoice = create_invoice(store: store)
      assert {:ok, _} = BitPal.Invoices.fetch(invoice.id)
    end

    test "different ways of specifying store", %{store: store} do
      assert create_invoice(store).store_id == store.id
      assert create_invoice(store: store).store_id == store.id
      assert create_invoice(store_id: store.id).store_id == store.id
    end

    test "create store if not specified" do
      assert create_invoice().store_id != nil
    end

    test "assigns existing address", %{store: store} do
      currency_id = unique_currency_id()
      address = create_address(store_id: store.id, currency_id: currency_id)
      invoice = create_invoice(store, address_id: address.id, currency_id: currency_id)
      assert invoice.address_id == address.id
    end

    test "assigns address_id and creates an Address", %{store: store} do
      address_id = unique_address_id()
      invoice = create_invoice(store, address_id: address_id)

      assert Repo.get!(Address, address_id)
      assert invoice.address_id == address_id
    end

    test "generates address with auto", %{store: store} do
      invoice = create_invoice(store, address_id: :auto)
      assert invoice.address_id != nil
      assert Repo.get!(Address, invoice.address_id)
    end

    test "specify currency" do
      currency_id = unique_currency_id()
      assert create_invoice(currency_id: currency_id).currency_id == currency_id
    end

    test "specify xpub", %{store: store} do
      xpub = "myxpub"
      invoice = create_invoice(store: store, address_key: xpub)
      address_key = StoreSettings.fetch_address_key!(store.id, invoice.currency_id)
      assert address_key.data == xpub
      {:ok, got_address_key} = Invoices.address_key(invoice)
      assert got_address_key.id == address_key.id
    end

    test "specify status generates status_reason", %{store: store} do
      assert create_invoice(store, status: :draft).status_reason == nil
      assert create_invoice(store, status: :open).status_reason == nil
      assert create_invoice(store, status: :processing).status_reason in [:verifying, :confirming]

      assert create_invoice(store, status: :uncollectible).status_reason in [
               :expired,
               :canceled,
               :timed_out,
               :double_spent
             ]

      assert create_invoice(store, status: :void).status_reason in [
               :expired,
               :canceled,
               :timed_out,
               :double_spent,
               nil
             ]

      assert create_invoice(store, status: :paid).status_reason == nil
    end
  end

  describe "with_address/2" do
    setup %{store: store} do
      %{store: store, invoice: create_invoice(store)}
    end

    test "pass through existing address", %{store: store, invoice: invoice} do
      address = create_address(store_id: store.id, currency_id: invoice.currency_id)

      invoice = with_address(invoice, address_id: address.id)
      assert invoice.address_id == address.id
    end

    test "create address_id", %{invoice: invoice} do
      address_id = unique_address_id()
      invoice = with_address(invoice, address_id: address_id)
      assert invoice.address_id == address_id
      assert Repo.get!(Address, address_id)
    end

    test "generates an address if nothing specified", %{invoice: invoice} do
      invoice = with_address(invoice)
      assert invoice.address_id != nil
      assert Repo.get!(Address, invoice.address_id)
    end
  end
end
