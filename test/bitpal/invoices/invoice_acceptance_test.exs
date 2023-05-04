defmodule BitPal.InvoiceAcceptanceTest do
  use BitPal.IntegrationCase, async: true

  test "accept after no double spend in timeout", %{currency_id: currency_id} do
    {:ok, inv, stub, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(
        required_confirmations: 0,
        double_spend_timeout: 1,
        payment_currency_id: currency_id
      )

    BackendMock.tx_seen(inv)

    HandlerSubscriberCollector.await_msg(stub, {:invoice, :paid})

    id = inv.id

    assert [
             {{:invoice, :finalized}, %{id: ^id, status: :open, address_id: _}},
             {{:invoice, :processing}, %{id: ^id, status: {:processing, :verifying}}},
             {{:invoice, :paid}, %{id: ^id}}
           ] = HandlerSubscriberCollector.received(stub)
  end

  test "accept when block is found while waiting for double spend timout", %{
    currency_id: currency_id
  } do
    {:ok, inv, stub, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(
        required_confirmations: 0,
        double_spend_timeout: 1_000,
        payment_currency_id: currency_id
      )

    BackendMock.tx_seen(inv)
    BackendMock.confirmed_in_new_block(inv)

    HandlerSubscriberCollector.await_msg(stub, {:invoice, :paid})

    assert [
             {{:invoice, :finalized}, _},
             {{:invoice, :processing}, %{status: {:processing, :verifying}}},
             {{:invoice, :paid}, _}
           ] = HandlerSubscriberCollector.received(stub)
  end

  test "accept after a confirmation", %{currency_id: currency_id} do
    {:ok, inv, stub, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(
        required_confirmations: 1,
        payment_currency_id: currency_id
      )

    BackendMock.tx_seen(inv)
    BackendMock.confirmed_in_new_block(inv)

    HandlerSubscriberCollector.await_msg(stub, {:invoice, :paid})

    assert [
             {{:invoice, :finalized}, _},
             {{:invoice, :processing},
              %{status: {:processing, :confirming}, confirmations_due: 1}},
             {{:invoice, :paid}, _}
           ] = HandlerSubscriberCollector.received(stub)
  end

  test "confirmed without being seen", %{currency_id: currency_id} do
    {:ok, inv, stub, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(
        required_confirmations: 1,
        payment_currency_id: currency_id
      )

    BackendMock.confirmed_in_new_block(inv)

    HandlerSubscriberCollector.await_msg(stub, {:invoice, :paid})

    assert [
             {{:invoice, :finalized}, _},
             {{:invoice, :processing},
              %{status: {:processing, :confirming}, confirmations_due: 0}},
             {{:invoice, :paid}, _}
           ] = HandlerSubscriberCollector.received(stub)
  end

  test "accepts after multiple confirmations", %{currency_id: currency_id} do
    {:ok, inv, stub, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(
        required_confirmations: 3,
        payment_currency_id: currency_id
      )

    BackendMock.tx_seen(inv)
    BackendMock.confirmed_in_new_block(inv)
    BackendMock.issue_blocks(currency_id, 5)

    HandlerSubscriberCollector.await_msg(stub, {:invoice, :paid})

    assert [
             {{:invoice, :finalized}, _},
             {{:invoice, :processing},
              %{status: {:processing, :confirming}, confirmations_due: 3}},
             {{:invoice, :processing},
              %{status: {:processing, :confirming}, confirmations_due: 2}},
             {{:invoice, :processing},
              %{status: {:processing, :confirming}, confirmations_due: 1}},
             {{:invoice, :paid}, _}
           ] = HandlerSubscriberCollector.received(stub)
  end

  test "multiple invoices", %{currency_id: currency_id} do
    {:ok, inv0, stub0, _} =
      HandlerSubscriberCollector.create_invoice(
        double_spend_timeout: 1,
        expected_payment: Money.parse!(0.1, currency_id),
        required_confirmations: 0
      )

    {:ok, inv1, stub1, _} =
      HandlerSubscriberCollector.create_invoice(
        double_spend_timeout: 1,
        expected_payment: Money.parse!(1.0, currency_id),
        required_confirmations: 1
      )

    {:ok, inv2, stub2, _} =
      HandlerSubscriberCollector.create_invoice(
        double_spend_timeout: 1,
        expected_payment: Money.parse!(2.0, currency_id),
        required_confirmations: 2
      )

    inv0_id = inv0.id
    inv1_id = inv1.id
    inv2_id = inv2.id

    BackendMock.tx_seen(inv0)
    BackendMock.tx_seen(inv1)
    HandlerSubscriberCollector.await_msg(stub0, {:invoice, :paid})
    HandlerSubscriberCollector.await_msg(stub1, {:invoice, :processing})

    assert [
             {{:invoice, :finalized}, %{id: ^inv0_id}},
             {{:invoice, :processing}, %{id: ^inv0_id, status: {:processing, :verifying}}},
             {{:invoice, :paid}, %{id: ^inv0_id}}
           ] = HandlerSubscriberCollector.received(stub0)

    assert [
             {{:invoice, :finalized}, %{id: ^inv1_id}},
             {{:invoice, :processing},
              %{id: ^inv1_id, status: {:processing, :confirming}, confirmations_due: 1}}
           ] = HandlerSubscriberCollector.received(stub1)

    assert [
             {{:invoice, :finalized}, %{id: ^inv2_id}}
           ] = HandlerSubscriberCollector.received(stub2)

    BackendMock.confirmed_in_new_block(inv2)
    HandlerSubscriberCollector.await_msg(stub2, {:invoice, :processing})

    assert [
             {{:invoice, :finalized}, %{id: ^inv1_id}},
             {{:invoice, :processing},
              %{id: ^inv1_id, status: {:processing, :confirming}, confirmations_due: 1}}
           ] = HandlerSubscriberCollector.received(stub1)

    assert [
             {{:invoice, :finalized}, %{id: ^inv2_id}},
             {{:invoice, :processing},
              %{id: ^inv2_id, status: {:processing, :confirming}, confirmations_due: 1}}
           ] = HandlerSubscriberCollector.received(stub2)

    BackendMock.issue_blocks(currency_id, 2)
    HandlerSubscriberCollector.await_msg(stub2, {:invoice, :paid})

    assert [
             {{:invoice, :finalized}, %{id: ^inv1_id}},
             {{:invoice, :processing},
              %{id: ^inv1_id, status: {:processing, :confirming}, confirmations_due: 1}}
           ] = HandlerSubscriberCollector.received(stub1)

    assert [
             {{:invoice, :finalized}, %{id: ^inv2_id}},
             {{:invoice, :processing},
              %{id: ^inv2_id, status: {:processing, :confirming}, confirmations_due: 1}},
             {{:invoice, :paid}, %{id: ^inv2_id}}
           ] = HandlerSubscriberCollector.received(stub2)
  end

  test "Invoices of the same amount", %{currency_id: currency_id} do
    inv = [expected_payment: Money.parse!(1.0, currency_id), required_confirmations: 1]

    {:ok, inv0, _, handler0} = HandlerSubscriberCollector.create_invoice(inv)
    {:ok, inv1, _, handler1} = HandlerSubscriberCollector.create_invoice(inv)

    assert inv0.expected_payment == inv1.expected_payment
    assert inv0.address_id != inv1.address_id
    assert handler0 != handler1
  end

  test "Detect early 0-conf doublespend", %{currency_id: currency_id} do
    {:ok, inv, stub, _} =
      HandlerSubscriberCollector.create_invoice(
        required_confirmations: 0,
        payment_currency_id: currency_id
      )

    BackendMock.tx_seen(inv)
    BackendMock.doublespend(inv)

    HandlerSubscriberCollector.await_msg(stub, {:invoice, :uncollectible})

    assert [
             {{:invoice, :finalized}, _},
             {{:invoice, :processing}, %{status: {:processing, :verifying}}},
             {{:invoice, :uncollectible}, %{status: {:uncollectible, :double_spent}}}
           ] = HandlerSubscriberCollector.received(stub)
  end

  test "Underpaid invoice", %{currency_id: currency_id} do
    {:ok, inv, stub, _handler} =
      HandlerSubscriberCollector.create_invoice(
        expected_payment: Money.parse!(1.0, currency_id),
        required_confirmations: 0,
        double_spend_timeout: 1
      )

    paid = Money.parse!(0.3, currency_id)
    BackendMock.tx_seen(%{inv | expected_payment: paid})

    HandlerSubscriberCollector.await_msg(stub, {:invoice, :underpaid})

    assert [
             {{:invoice, :finalized}, _},
             {{:invoice, :underpaid}, %{amount_paid: ^paid, txs: [_]}}
           ] = HandlerSubscriberCollector.received(stub)

    paid2 = Money.parse!(0.7, currency_id)
    BackendMock.tx_seen(%{inv | expected_payment: paid2})
    HandlerSubscriberCollector.await_msg(stub, {:invoice, :paid})

    fully_paid = Money.add(paid, paid2)

    assert [
             {{:invoice, :finalized}, _},
             {{:invoice, :underpaid}, %{amount_paid: ^paid, txs: [_]}},
             {{:invoice, :processing}, %{status: {:processing, :verifying}}},
             {{:invoice, :paid}, %{amount_paid: ^fully_paid, txs: [_, _]}}
           ] = HandlerSubscriberCollector.received(stub)
  end

  test "Overpaid invoice", %{currency_id: currency_id} do
    {:ok, inv, stub, _handler} =
      HandlerSubscriberCollector.create_invoice(
        expected_payment: Money.parse!(1.0, currency_id),
        required_confirmations: 0,
        double_spend_timeout: 1
      )

    amount1 = Money.parse!(0.3, currency_id)
    BackendMock.tx_seen(%{inv | expected_payment: amount1})
    HandlerSubscriberCollector.await_msg(stub, {:invoice, :underpaid})

    amount2 = Money.parse!(1.3, currency_id)
    BackendMock.tx_seen(%{inv | expected_payment: amount2})
    HandlerSubscriberCollector.await_msg(stub, {:invoice, :paid})

    total_paid = Money.add(amount1, amount2)

    assert [
             {{:invoice, :finalized}, _},
             {{:invoice, :underpaid}, %{amount_paid: ^amount1, txs: [_]}},
             {{:invoice, :overpaid}, %{amount_paid: ^total_paid, txs: [_, _]}},
             {{:invoice, :processing}, %{status: {:processing, :verifying}}},
             {{:invoice, :paid}, %{amount_paid: ^total_paid, txs: [_, _]}}
           ] = HandlerSubscriberCollector.received(stub)
  end
end
