defmodule BitPal.StoreTest do
  use BitPal.IntegrationCase, db: true, async: false
  alias BitPal.Repo
  alias BitPal.Stores

  test "store invoice association" do
    store = Stores.create!(label: "My Store")
    assert store.label == "My Store"

    assert {:ok, invoice} =
             Invoices.register(
               store.id,
               %{
                 amount: "1.2",
                 currency: "BCH",
                 exchange_rate: "2.0",
                 fiat_currency: "USD"
               }
             )

    store = Repo.preload(store, [:invoices])
    assert length(store.invoices) == 1
    assert invoice.store_id == store.id
  end
end
