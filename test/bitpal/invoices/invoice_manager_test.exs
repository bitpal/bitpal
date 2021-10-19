defmodule InvoiceManagerTest do
  use BitPal.IntegrationCase
  alias BitPal.Currencies
  alias BitPal.InvoiceManager

  @tag backends: true
  test "initialize" do
    Currencies.register!(:BCH)
    store = Stores.create!()

    assert {:ok, inv1} =
             Invoices.register(store.id, %{
               amount: 2.5,
               exchange_rate: 1.1,
               currency: "BCH",
               fiat_currency: "USD"
             })

    assert {:ok, inv1_id} = InvoiceManager.finalize_and_track(inv1)

    assert {:ok, inv2} =
             Invoices.register(store.id, %{
               amount: 5.2,
               exchange_rate: 1.1,
               currency: "BCH",
               fiat_currency: "USD"
             })

    assert {:ok, inv2_id} = InvoiceManager.finalize_and_track(inv2)

    assert inv1_id != inv2_id
    assert {:ok, inv1_pid} = InvoiceManager.fetch_handler(inv1_id)
    assert {:ok, inv2_pid} = InvoiceManager.fetch_handler(inv2_id)
    assert inv1_pid != inv2_pid
    assert InvoiceManager.count_children() == 2

    assert_shutdown(inv2_pid)

    assert InvoiceManager.count_children() == 2
  end
end
