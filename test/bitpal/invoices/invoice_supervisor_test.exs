defmodule InvoiceSupervisorTest do
  use BitPal.IntegrationCase, async: true
  alias BitPal.InvoiceSupervisor

  setup tags do
    name = unique_server_name()
    start_supervised!({InvoiceSupervisor, name: name})

    Map.put(tags, :name, name)
  end

  describe "finalize_invoice/2" do
    test "initialize", %{currency_id: currency_id, name: name} do
      inv1 = create_invoice(payment_currency_id: currency_id)

      assert {:ok, got_inv1} = InvoiceSupervisor.finalize_invoice(inv1, name: name)
      assert inv1.id == got_inv1.id

      inv2 = create_invoice(payment_currency_id: currency_id)
      assert {:ok, got_inv2} = InvoiceSupervisor.finalize_invoice(inv2, name: name)
      assert inv2.id == got_inv2.id

      assert inv1.id != inv2.id
      assert {:ok, inv1_pid} = InvoiceSupervisor.fetch_handler(inv1.id)
      assert {:ok, inv2_pid} = InvoiceSupervisor.fetch_handler(inv2.id)
      assert inv1_pid != inv2_pid

      assert InvoiceSupervisor.count_children(name) == 2

      assert_shutdown(inv2_pid)
      assert InvoiceSupervisor.count_children(name) == 2
    end

    test "finalizes", %{currency_id: currency_id, name: name} do
      inv = create_invoice(payment_currency_id: currency_id, status: :draft)
      assert {:ok, got_inv} = InvoiceSupervisor.finalize_invoice(inv, name: name)
      assert inv.id == got_inv.id
      assert got_inv.status == :open
    end
  end

  describe "ensure_handler/2" do
    test "associates handler with already finalized invoice", %{
      currency_id: currency_id,
      name: name
    } do
      inv = create_invoice(payment_currency_id: currency_id, status: :open)
      assert inv.status == :open
      assert {:ok, handler} = InvoiceSupervisor.ensure_handler(inv, name: name)
      assert is_pid(handler)
      assert {:ok, ^handler} = InvoiceSupervisor.fetch_handler(inv.id)
    end
  end
end
