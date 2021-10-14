defmodule BitPal.StoreTest do
  use BitPal.IntegrationCase, db: true, async: false
  alias BitPal.Repo
  alias BitPal.Stores

  setup tags do
    %{store: create_store(tags) |> Repo.preload([:users])}
  end

  test "store invoice association", %{store: store} do
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
