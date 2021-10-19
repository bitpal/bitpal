defmodule BitPal.InvoiceAcceptanceTest do
  use BitPal.IntegrationCase
  alias BitPal.BackendMock

  @tag backends: true, double_spend_timeout: 1
  test "accept after no double spend in timeout" do
    {:ok, inv, stub, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(required_confirmations: 0)

    BackendMock.tx_seen(inv)

    HandlerSubscriberCollector.await_msg(stub, :invoice_paid)

    id = inv.id

    assert [
             {:invoice_finalized, %{id: ^id, status: :open, address_id: _}},
             {:invoice_processing, %{id: ^id, reason: :verifying}},
             {:invoice_paid, %{id: ^id}}
           ] = HandlerSubscriberCollector.received(stub)
  end

  @tag backends: true, double_spend_timeout: 1_000
  test "accept when block is found while waiting for double spend timout" do
    {:ok, inv, stub, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(required_confirmations: 0)

    BackendMock.tx_seen(inv)
    BackendMock.confirmed_in_new_block(inv)

    HandlerSubscriberCollector.await_msg(stub, :invoice_paid)

    assert [
             {:invoice_finalized, _},
             {:invoice_processing, %{reason: :verifying}},
             {:invoice_paid, _}
           ] = HandlerSubscriberCollector.received(stub)
  end

  @tag backends: true
  test "accept after a confirmation" do
    {:ok, inv, stub, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(required_confirmations: 1)

    BackendMock.tx_seen(inv)
    BackendMock.confirmed_in_new_block(inv)

    HandlerSubscriberCollector.await_msg(stub, :invoice_paid)

    assert [
             {:invoice_finalized, _},
             {:invoice_processing, %{reason: {:confirming, 1}}},
             {:invoice_paid, _}
           ] = HandlerSubscriberCollector.received(stub)
  end

  @tag backends: true
  test "confirmed without being seen" do
    {:ok, inv, stub, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(required_confirmations: 1)

    BackendMock.confirmed_in_new_block(inv)

    HandlerSubscriberCollector.await_msg(stub, :invoice_paid)

    assert [
             {:invoice_finalized, _},
             {:invoice_processing, %{reason: {:confirming, 0}}},
             {:invoice_paid, _}
           ] = HandlerSubscriberCollector.received(stub)
  end

  @tag backends: true, many: true
  test "accepts after multiple confirmations" do
    {:ok, inv, stub, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(required_confirmations: 3)

    BackendMock.tx_seen(inv)
    BackendMock.confirmed_in_new_block(inv)
    BackendMock.issue_blocks(5)

    HandlerSubscriberCollector.await_msg(stub, :invoice_paid)

    assert [
             {:invoice_finalized, _},
             {:invoice_processing, %{reason: {:confirming, 3}}},
             {:invoice_processing, %{reason: {:confirming, 2}}},
             {:invoice_processing, %{reason: {:confirming, 1}}},
             {:invoice_paid, _}
           ] = HandlerSubscriberCollector.received(stub)
  end

  @tag backends: true, double_spend_timeout: 1, multi: true
  test "multiple invoices" do
    {:ok, inv0, stub0, _} =
      HandlerSubscriberCollector.create_invoice(
        amount: 0.1,
        required_confirmations: 0
      )

    {:ok, inv1, stub1, _} =
      HandlerSubscriberCollector.create_invoice(
        amount: 1.0,
        required_confirmations: 1
      )

    {:ok, inv2, stub2, _} =
      HandlerSubscriberCollector.create_invoice(
        amount: 2.0,
        required_confirmations: 2
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

    BackendMock.issue_blocks(2)
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

  @tag backends: true
  test "Invoices of the same amount" do
    inv = [amount: 1.0, required_confirmations: 1]

    {:ok, inv0, _, handler0} = HandlerSubscriberCollector.create_invoice(inv)
    {:ok, inv1, _, handler1} = HandlerSubscriberCollector.create_invoice(inv)

    assert inv0.amount == inv1.amount
    assert inv0.address_id != inv1.address_id
    assert handler0 != handler1
  end

  @tag backends: true, double_spend_timeout: 1_000
  test "Detect early 0-conf doublespend" do
    {:ok, inv, stub, _} = HandlerSubscriberCollector.create_invoice(required_confirmations: 0)

    BackendMock.tx_seen(inv)
    BackendMock.doublespend(inv)

    HandlerSubscriberCollector.await_msg(stub, :invoice_uncollectible)

    assert [
             {:invoice_finalized, _},
             {:invoice_processing, %{reason: :verifying}},
             {:invoice_uncollectible, %{reason: :double_spent}}
           ] = HandlerSubscriberCollector.received(stub)
  end

  @tag backends: true, double_spend_timeout: 1
  test "Underpaid invoice" do
    {:ok, inv, stub, _handler} =
      HandlerSubscriberCollector.create_invoice(amount: 1.0, required_confirmations: 0)

    BackendMock.tx_seen(%{inv | amount: Money.parse!(0.3, :BCH)})

    HandlerSubscriberCollector.await_msg(stub, :invoice_underpaid)
    due = Money.parse!(0.7, :BCH)

    assert [
             {:invoice_finalized, _},
             {:invoice_underpaid, %{amount_due: ^due}}
           ] = HandlerSubscriberCollector.received(stub)

    BackendMock.tx_seen(%{inv | amount: Money.parse!(0.7, :BCH)})
    HandlerSubscriberCollector.await_msg(stub, :invoice_paid)

    assert [
             {:invoice_finalized, _},
             {:invoice_underpaid, %{amount_due: ^due}},
             {:invoice_processing, %{reason: :verifying}},
             {:invoice_paid, _}
           ] = HandlerSubscriberCollector.received(stub)
  end

  @tag backends: true, double_spend_timeout: 1
  test "Overpaid invoice" do
    {:ok, inv, stub, _handler} =
      HandlerSubscriberCollector.create_invoice(amount: 1.0, required_confirmations: 0)

    BackendMock.tx_seen(%{inv | amount: Money.parse!(0.3, :BCH)})
    HandlerSubscriberCollector.await_msg(stub, :invoice_underpaid)

    BackendMock.tx_seen(%{inv | amount: Money.parse!(1.3, :BCH)})
    HandlerSubscriberCollector.await_msg(stub, :invoice_paid)

    due = Money.parse!(0.7, :BCH)
    overpaid = Money.parse!(0.6, :BCH)

    assert [
             {:invoice_finalized, _},
             {:invoice_underpaid, %{amount_due: ^due}},
             {:invoice_overpaid, %{overpaid_amount: ^overpaid}},
             {:invoice_processing, %{reason: :verifying}},
             {:invoice_paid, _}
           ] = HandlerSubscriberCollector.received(stub)
  end
end
