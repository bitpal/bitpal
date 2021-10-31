defmodule BitPal.InvoiceAcceptanceTest do
  use BitPal.IntegrationCase, async: true

  test "accept after no double spend in timeout", %{currency_id: currency_id} do
    {:ok, inv, stub, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(
        required_confirmations: 0,
        double_spend_timeout: 1,
        currency_id: currency_id
      )

    BackendMock.tx_seen(inv)

    HandlerSubscriberCollector.await_msg(stub, :invoice_paid)

    id = inv.id

    assert [
             {:invoice_finalized, %{id: ^id, status: :open, address_id: _}},
             {:invoice_processing, %{id: ^id, reason: :verifying}},
             {:invoice_paid, %{id: ^id}}
           ] = HandlerSubscriberCollector.received(stub)
  end

  test "accept when block is found while waiting for double spend timout", %{
    currency_id: currency_id
  } do
    {:ok, inv, stub, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(
        required_confirmations: 0,
        double_spend_timeout: 1_000,
        currency_id: currency_id
      )

    BackendMock.tx_seen(inv)
    BackendMock.confirmed_in_new_block(inv)

    HandlerSubscriberCollector.await_msg(stub, :invoice_paid)

    assert [
             {:invoice_finalized, _},
             {:invoice_processing, %{reason: :verifying}},
             {:invoice_paid, _}
           ] = HandlerSubscriberCollector.received(stub)
  end

  test "accept after a confirmation", %{currency_id: currency_id} do
    {:ok, inv, stub, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(
        required_confirmations: 1,
        currency_id: currency_id
      )

    BackendMock.tx_seen(inv)
    BackendMock.confirmed_in_new_block(inv)

    HandlerSubscriberCollector.await_msg(stub, :invoice_paid)

    assert [
             {:invoice_finalized, _},
             {:invoice_processing, %{reason: {:confirming, 1}}},
             {:invoice_paid, _}
           ] = HandlerSubscriberCollector.received(stub)
  end

  test "confirmed without being seen", %{currency_id: currency_id} do
    {:ok, inv, stub, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(
        required_confirmations: 1,
        currency_id: currency_id
      )

    BackendMock.confirmed_in_new_block(inv)

    HandlerSubscriberCollector.await_msg(stub, :invoice_paid)

    assert [
             {:invoice_finalized, _},
             {:invoice_processing, %{reason: {:confirming, 0}}},
             {:invoice_paid, _}
           ] = HandlerSubscriberCollector.received(stub)
  end

  test "accepts after multiple confirmations", %{currency_id: currency_id} do
    {:ok, inv, stub, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(
        required_confirmations: 3,
        currency_id: currency_id
      )

    BackendMock.tx_seen(inv)
    BackendMock.confirmed_in_new_block(inv)
    BackendMock.issue_blocks(currency_id, 5)

    HandlerSubscriberCollector.await_msg(stub, :invoice_paid)

    assert [
             {:invoice_finalized, _},
             {:invoice_processing, %{reason: {:confirming, 3}}},
             {:invoice_processing, %{reason: {:confirming, 2}}},
             {:invoice_processing, %{reason: {:confirming, 1}}},
             {:invoice_paid, _}
           ] = HandlerSubscriberCollector.received(stub)
  end

  test "multiple invoices", %{currency_id: currency_id} do
    {:ok, inv0, stub0, _} =
      HandlerSubscriberCollector.create_invoice(
        double_spend_timeout: 1,
        amount: 0.1,
        required_confirmations: 0,
        currency_id: currency_id
      )

    {:ok, inv1, stub1, _} =
      HandlerSubscriberCollector.create_invoice(
        double_spend_timeout: 1,
        amount: 1.0,
        required_confirmations: 1,
        currency_id: currency_id
      )

    {:ok, inv2, stub2, _} =
      HandlerSubscriberCollector.create_invoice(
        double_spend_timeout: 1,
        amount: 2.0,
        required_confirmations: 2,
        currency_id: currency_id
      )

    inv0_id = inv0.id
    inv1_id = inv1.id
    inv2_id = inv2.id

    BackendMock.tx_seen(inv0)
    BackendMock.tx_seen(inv1)
    HandlerSubscriberCollector.await_msg(stub0, :invoice_paid)
    HandlerSubscriberCollector.await_msg(stub1, :invoice_processing)

    assert [
             {:invoice_finalized, %{id: ^inv0_id}},
             {:invoice_processing, %{id: ^inv0_id, reason: :verifying}},
             {:invoice_paid, %{id: ^inv0_id}}
           ] = HandlerSubscriberCollector.received(stub0)

    assert [
             {:invoice_finalized, %{id: ^inv1_id}},
             {:invoice_processing, %{id: ^inv1_id, reason: {:confirming, 1}}}
           ] = HandlerSubscriberCollector.received(stub1)

    assert [
             {:invoice_finalized, %{id: ^inv2_id}}
           ] = HandlerSubscriberCollector.received(stub2)

    BackendMock.confirmed_in_new_block(inv2)
    HandlerSubscriberCollector.await_msg(stub2, :invoice_processing)

    assert [
             {:invoice_finalized, %{id: ^inv1_id}},
             {:invoice_processing, %{id: ^inv1_id, reason: {:confirming, 1}}}
           ] = HandlerSubscriberCollector.received(stub1)

    assert [
             {:invoice_finalized, %{id: ^inv2_id}},
             {:invoice_processing, %{id: ^inv2_id, reason: {:confirming, 1}}}
           ] = HandlerSubscriberCollector.received(stub2)

    BackendMock.issue_blocks(currency_id, 2)
    HandlerSubscriberCollector.await_msg(stub2, :invoice_paid)

    assert [
             {:invoice_finalized, %{id: ^inv1_id}},
             {:invoice_processing, %{id: ^inv1_id, reason: {:confirming, 1}}}
           ] = HandlerSubscriberCollector.received(stub1)

    assert [
             {:invoice_finalized, %{id: ^inv2_id}},
             {:invoice_processing, %{id: ^inv2_id, reason: {:confirming, 1}}},
             {:invoice_paid, %{id: ^inv2_id}}
           ] = HandlerSubscriberCollector.received(stub2)
  end

  test "Invoices of the same amount", %{currency_id: currency_id} do
    inv = [amount: 1.0, required_confirmations: 1, currency_id: currency_id]

    {:ok, inv0, _, handler0} = HandlerSubscriberCollector.create_invoice(inv)
    {:ok, inv1, _, handler1} = HandlerSubscriberCollector.create_invoice(inv)

    assert inv0.amount == inv1.amount
    assert inv0.address_id != inv1.address_id
    assert handler0 != handler1
  end

  test "Detect early 0-conf doublespend", %{currency_id: currency_id} do
    {:ok, inv, stub, _} =
      HandlerSubscriberCollector.create_invoice(
        required_confirmations: 0,
        currency_id: currency_id
      )

    BackendMock.tx_seen(inv)
    BackendMock.doublespend(inv)

    HandlerSubscriberCollector.await_msg(stub, :invoice_uncollectible)

    assert [
             {:invoice_finalized, _},
             {:invoice_processing, %{reason: :verifying}},
             {:invoice_uncollectible, %{reason: :double_spent}}
           ] = HandlerSubscriberCollector.received(stub)
  end

  test "Underpaid invoice", %{currency_id: currency_id} do
    {:ok, inv, stub, _handler} =
      HandlerSubscriberCollector.create_invoice(
        amount: 1.0,
        required_confirmations: 0,
        double_spend_timeout: 1,
        currency_id: currency_id
      )

    BackendMock.tx_seen(%{inv | amount: Money.parse!(0.3, currency_id)})

    HandlerSubscriberCollector.await_msg(stub, :invoice_underpaid)
    due = Money.parse!(0.7, currency_id)

    assert [
             {:invoice_finalized, _},
             {:invoice_underpaid, %{amount_due: ^due}}
           ] = HandlerSubscriberCollector.received(stub)

    BackendMock.tx_seen(%{inv | amount: Money.parse!(0.7, currency_id)})
    HandlerSubscriberCollector.await_msg(stub, :invoice_paid)

    assert [
             {:invoice_finalized, _},
             {:invoice_underpaid, %{amount_due: ^due}},
             {:invoice_processing, %{reason: :verifying}},
             {:invoice_paid, _}
           ] = HandlerSubscriberCollector.received(stub)
  end

  test "Overpaid invoice", %{currency_id: currency_id} do
    {:ok, inv, stub, _handler} =
      HandlerSubscriberCollector.create_invoice(
        amount: 1.0,
        required_confirmations: 0,
        double_spend_timeout: 1,
        currency_id: currency_id
      )

    BackendMock.tx_seen(%{inv | amount: Money.parse!(0.3, currency_id)})
    HandlerSubscriberCollector.await_msg(stub, :invoice_underpaid)

    BackendMock.tx_seen(%{inv | amount: Money.parse!(1.3, currency_id)})
    HandlerSubscriberCollector.await_msg(stub, :invoice_paid)

    due = Money.parse!(0.7, currency_id)
    overpaid = Money.parse!(0.6, currency_id)

    assert [
             {:invoice_finalized, _},
             {:invoice_underpaid, %{amount_due: ^due}},
             {:invoice_overpaid, %{overpaid_amount: ^overpaid}},
             {:invoice_processing, %{reason: :verifying}},
             {:invoice_paid, _}
           ] = HandlerSubscriberCollector.received(stub)
  end
end
