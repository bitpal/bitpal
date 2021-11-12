defmodule BitPal.StoreTest do
  use BitPal.DataCase, async: true
  alias BitPal.Repo

  setup _tags do
    %{store: create_store() |> Repo.preload([:users])}
  end

  test "store invoice association", %{store: store} do
    assert {:ok, invoice} =
             Invoices.register(
               store.id,
               %{
                 amount: "1.2",
                 currency_id: unique_currency_id(),
                 exchange_rate: "2.0",
                 fiat_currency: fiat_currency()
               }
             )

    store = Repo.preload(store, [:invoices])
    assert length(store.invoices) == 1
    assert invoice.store_id == store.id
  end
end
