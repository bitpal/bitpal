defmodule BitPal.InvoiceRecoveryTest do
  use BitPal.IntegrationCase
  alias BitPal.InvoiceHandler

  @tag backends: true
  test "invoice recover status and continue" do
    {:ok, inv, stub, handler} =
      HandlerSubscriberCollector.create_invoice(required_confirmations: 1)

    assert inv.status == :open

    BackendMock.tx_seen(inv)
    HandlerSubscriberCollector.await_msg(stub, :invoice_processing)

    inv = Invoices.fetch!(inv.id)
    assert inv.status == :processing

    # Make sure handler is killed
    assert_shutdown(handler)
    # Then wait for it to be restarted
    handler = wait_for_handler(inv.id, handler)

    inv = InvoiceHandler.get_invoice(handler)
    assert inv.status == :processing

    BackendMock.confirmed_in_new_block(inv)

    HandlerSubscriberCollector.await_msg(stub, :invoice_paid)
  end

  @tag backends: true, double_spend_timeout: 1, do: true
  test "invoice recover missing tx seen" do
    {:ok, inv, stub, _handler} =
      HandlerSubscriberCollector.create_invoice(required_confirmations: 0)

    assert inv.status == :open

    # Terminate on the top level to prevent handler from being restarted before we've added
    # things that we want it to recover from.
    InvoiceManager.terminate_children()

    BackendMock.tx_seen(inv)

    InvoiceManager.finalize_and_track(inv)

    HandlerSubscriberCollector.await_msg(stub, :invoice_paid)
  end

  @tag backends: true
  test "invoice recover missing confirmation" do
    {:ok, inv, stub, _handler} =
      HandlerSubscriberCollector.create_invoice(required_confirmations: 1)

    assert inv.status == :open

    BackendMock.tx_seen(inv)
    HandlerSubscriberCollector.await_msg(stub, :invoice_processing)

    inv = Invoices.fetch!(inv.id)
    assert inv.status == :processing

    # Terminate on the top level to prevent handler from being restarted before we've added
    # things that we want it to recover from.
    InvoiceManager.terminate_children()

    BackendMock.confirmed_in_new_block(inv)

    InvoiceManager.finalize_and_track(inv)

    HandlerSubscriberCollector.await_msg(stub, :invoice_paid)
  end

  defp wait_for_handler(invoice_id, prev_handler) do
    case InvoiceManager.get_handler(invoice_id) do
      {:ok, ^prev_handler} ->
        Process.sleep(10)
        wait_for_handler(invoice_id, prev_handler)

      {:ok, handler} ->
        handler

      _ ->
        Process.sleep(10)
        wait_for_handler(invoice_id, prev_handler)
    end
  end
end
