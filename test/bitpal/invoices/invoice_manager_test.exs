defmodule InvoiceManagerTest do
  use BitPal.IntegrationCase, async: true
  alias BitPal.InvoiceManager

  test "initialize", %{currency_id: currency_id} do
    name = unique_server_name()

    start_supervised!({InvoiceManager, name: name})

    inv1 = InvoiceFixtures.invoice_fixture(currency_id: currency_id)
    assert {:ok, got_inv1} = InvoiceManager.finalize_invoice(inv1, parent: self(), name: name)
    assert inv1.id == got_inv1.id

    inv2 = InvoiceFixtures.invoice_fixture(currency_id: currency_id)
    assert {:ok, got_inv2} = InvoiceManager.finalize_invoice(inv2, parent: self(), name: name)
    assert inv2.id == got_inv2.id

    assert inv1.id != inv2.id
    assert {:ok, inv1_pid} = InvoiceManager.fetch_handler(inv1.id)
    assert {:ok, inv2_pid} = InvoiceManager.fetch_handler(inv2.id)
    assert inv1_pid != inv2_pid

    assert InvoiceManager.count_children(name) == 2

    assert_shutdown(inv2_pid)
    assert InvoiceManager.count_children(name) == 2
  end
end
