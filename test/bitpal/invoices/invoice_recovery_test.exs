defmodule BitPal.InvoiceRecoveryTest do
  use BitPal.IntegrationCase, async: true
  alias BitPal.InvoiceHandler

  test "invoice recover status and continue", %{currency_id: currency_id} do
    {:ok, inv, stub, handler} =
      HandlerSubscriberCollector.create_invoice(
        required_confirmations: 1,
        payment_currency_id: currency_id
      )

    assert inv.status == :open

    BackendMock.tx_seen(inv)
    HandlerSubscriberCollector.await_msg(stub, {:invoice, :processing})

    inv = Invoices.fetch!(inv.id)
    assert inv.status == {:processing, :confirming}

    # Make sure handler is killed
    assert_shutdown(handler)
    # Then wait for it to be restarted
    handler = wait_for_handler(inv.id, handler)

    inv = InvoiceHandler.fetch_invoice!(handler)
    assert inv.status == {:processing, :confirming}

    BackendMock.confirmed_in_new_block(inv)

    HandlerSubscriberCollector.await_msg(stub, {:invoice, :paid})
  end

  test "invoice recover missing tx seen", %{currency_id: currency_id} do
    {:ok, inv, stub, handler} =
      HandlerSubscriberCollector.create_invoice(
        required_confirmations: 0,
        double_spend_timeout: 1,
        payment_currency_id: currency_id
      )

    assert inv.status == :open

    # Terminate on the top level to prevent handler from being restarted before we've added
    # things that we want it to recover from.
    InvoiceSupervisor.terminate_handler(handler)

    BackendMock.tx_seen(inv)

    # Normally double_spend_timeout is kept after a restart, but
    # as we're terminating it via the supervisor it's lost, so we
    # have to repeat ourselves here.
    InvoiceSupervisor.finalize_invoice(inv, double_spend_timeout: 1)

    HandlerSubscriberCollector.await_msg(stub, {:invoice, :paid})
  end

  test "invoice recover missing confirmation", %{currency_id: currency_id} do
    {:ok, inv, stub, handler} =
      HandlerSubscriberCollector.create_invoice(
        required_confirmations: 1,
        payment_currency_id: currency_id
      )

    assert inv.status == :open

    BackendMock.tx_seen(inv)
    HandlerSubscriberCollector.await_msg(stub, {:invoice, :processing})

    inv = Invoices.fetch!(inv.id)
    assert inv.status == {:processing, :confirming}

    # Terminate on the top level to prevent handler from being restarted before we've added
    # things that we want it to recover from.
    InvoiceSupervisor.terminate_handler(handler)

    BackendMock.confirmed_in_new_block(inv)

    InvoiceSupervisor.finalize_invoice(inv)

    HandlerSubscriberCollector.await_msg(stub, {:invoice, :paid})
  end

  defp wait_for_handler(invoice_id, prev_handler) do
    case InvoiceSupervisor.fetch_handler(invoice_id) do
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
