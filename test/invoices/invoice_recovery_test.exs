defmodule BitPal.InvoiceRecoveryTest do
  use BitPal.IntegrationCase
  alias BitPal.InvoiceHandler

  @tag backends: true
  test "invoice recover status and continue" do
    {:ok, inv, stub, handler} =
      HandlerSubscriberCollector.create_invoice(required_confirmations: 1)

    assert inv.status == :open

    BackendMock.tx_seen(inv)
    HandlerSubscriberCollector.await_status(stub, :processing)

    inv = Invoices.fetch!(inv.id)
    assert inv.status == :processing

    # Make sure handler is killed
    assert_shutdown(handler)
    wait_for_unregister(handler)
    # Then wait for it to be restarted
    handler = wait_for_handler(inv.id)

    inv = InvoiceHandler.get_invoice(handler)
    assert inv.status == :processing

    BackendMock.confirmed_in_new_block(inv)

    HandlerSubscriberCollector.await_status(stub, :paid)
  end

  @tag backends: true
  test "invoice recover missing confirmation" do
    {:ok, inv, stub, handler} =
      HandlerSubscriberCollector.create_invoice(required_confirmations: 1)

    assert inv.status == :open

    BackendMock.tx_seen(inv)
    HandlerSubscriberCollector.await_status(stub, :processing)

    inv = Invoices.fetch!(inv.id)
    assert inv.status == :processing

    # Make sure handler is killed
    assert_shutdown(handler)
    wait_for_unregister(handler)

    BackendMock.confirmed_in_new_block(inv)
    # FIXME Maybe need to wait for something specific here?
    Process.sleep(50)

    handler = wait_for_handler(inv.id)

    HandlerSubscriberCollector.await_status(stub, :paid)
  end

  defp wait_for_unregister(invoice_id) do
    case InvoiceManager.get_handler(invoice_id) do
      {:ok, _} ->
        Process.sleep(10)
        wait_for_unregister(invoice_id)

      _ ->
        :ok
    end
  end

  defp wait_for_handler(invoice_id) do
    case InvoiceManager.get_handler(invoice_id) do
      {:ok, handler} ->
        handler

      _ ->
        Process.sleep(10)
        wait_for_handler(invoice_id)
    end
  end
end
