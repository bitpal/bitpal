defmodule InvoiceManagerTest do
  use BitPal.BackendCase
  alias BitPal.InvoiceManager

  test "initialize" do
    inv1 = invoice()
    {:ok, inv1_pid} = InvoiceManager.create_invoice(inv1)

    inv2 = invoice(amount: 5.2)
    {:ok, inv2_pid} = InvoiceManager.create_invoice(inv2)

    assert inv1_pid != inv2_pid
    assert InvoiceManager.count_children() == 2

    assert_shutdown(inv2_pid)

    assert InvoiceManager.count_children() == 2
  end
end
