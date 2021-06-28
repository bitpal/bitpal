defmodule BitPal.InvoiceAcceptanceTest do
  use BitPal.IntegrationCase
  alias BitPal.BackendMock

  @tag backends: true, double_spend_timeout: 1
  test "accept after no double spend in timeout" do
    {:ok, inv, stub, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(required_confirmations: 0)

    BackendMock.tx_seen(inv)

    HandlerSubscriberCollector.await_status(stub, :paid)

    assert [
             {:invoice_status, :open, _},
             {:invoice_status, :processing, _},
             {:invoice_status, :paid, _}
           ] = HandlerSubscriberCollector.received(stub)
  end

  @tag backends: true, double_spend_timeout: 1_000, run: true
  test "accept when block is found while waiting for double spend timout" do
    {:ok, inv, stub, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(required_confirmations: 0)

    BackendMock.tx_seen(inv)
    BackendMock.confirmed_in_new_block(inv)

    HandlerSubscriberCollector.await_status(stub, :paid)

    assert [
             {:invoice_status, :open, _},
             {:invoice_status, :processing, _},
             {:invoice_status, :paid, _}
           ] = HandlerSubscriberCollector.received(stub)
  end

  @tag backends: true
  test "accept after a confirmation" do
    {:ok, inv, stub, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(required_confirmations: 1)

    BackendMock.tx_seen(inv)
    BackendMock.confirmed_in_new_block(inv)

    HandlerSubscriberCollector.await_status(stub, :paid)

    assert [
             {:invoice_status, :open, _},
             {:invoice_status, :processing, _},
             {:invoice_status, :paid, _}
           ] = HandlerSubscriberCollector.received(stub)
  end

  @tag backends: true
  test "confirmed without being seen" do
    {:ok, inv, stub, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(required_confirmations: 1)

    BackendMock.confirmed_in_new_block(inv)

    HandlerSubscriberCollector.await_status(stub, :paid)

    assert [
             {:invoice_status, :open, _},
             {:invoice_status, :processing, _},
             {:invoice_status, :paid, _}
           ] = HandlerSubscriberCollector.received(stub)
  end

  @tag backends: true, many: true
  test "accepts after multiple confirmations" do
    {:ok, inv, stub, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(required_confirmations: 3)

    BackendMock.tx_seen(inv)
    BackendMock.confirmed_in_new_block(inv)
    BackendMock.issue_blocks(5)

    HandlerSubscriberCollector.await_status(stub, :paid)

    assert [
             {:invoice_status, :open, _},
             {:invoice_status, :processing, _},
             {:invoice_status, :paid, _}
           ] = HandlerSubscriberCollector.received(stub)
  end

  @tag backends: true, double_spend_timeout: 1, multi: true
  test "multiple invoices" do
    {:ok, inv0, stub0, _} =
      HandlerSubscriberCollector.create_invoice(
        amount: Money.parse!(0.1, :BCH),
        required_confirmations: 0
      )

    {:ok, inv1, stub1, _} =
      HandlerSubscriberCollector.create_invoice(
        amount: Money.parse!(1.0, :BCH),
        required_confirmations: 1
      )

    {:ok, inv2, stub2, _} =
      HandlerSubscriberCollector.create_invoice(
        amount: Money.parse!(2.0, :BCH),
        required_confirmations: 2
      )

    BackendMock.tx_seen(inv0)
    BackendMock.tx_seen(inv1)
    HandlerSubscriberCollector.await_status(stub0, :paid)
    HandlerSubscriberCollector.await_status(stub1, :processing)

    assert [
             {:invoice_status, :open, _},
             {:invoice_status, :processing, _},
             {:invoice_status, :paid, _}
           ] = HandlerSubscriberCollector.received(stub0)

    assert [
             {:invoice_status, :open, _},
             {:invoice_status, :processing, _}
           ] = HandlerSubscriberCollector.received(stub1)

    assert [
             {:invoice_status, :open, _}
           ] = HandlerSubscriberCollector.received(stub2)

    BackendMock.confirmed_in_new_block(inv2)
    HandlerSubscriberCollector.await_status(stub2, :processing)

    assert [
             {:invoice_status, :open, _},
             {:invoice_status, :processing, _}
           ] = HandlerSubscriberCollector.received(stub1)

    assert [
             {:invoice_status, :open, _},
             {:invoice_status, :processing, _}
           ] = HandlerSubscriberCollector.received(stub2)

    BackendMock.issue_blocks(2)
    HandlerSubscriberCollector.await_status(stub2, :paid)

    assert [
             {:invoice_status, :open, _},
             {:invoice_status, :processing, _}
           ] = HandlerSubscriberCollector.received(stub1)

    assert [
             {:invoice_status, :open, _},
             {:invoice_status, :processing, _},
             {:invoice_status, :paid, _}
           ] = HandlerSubscriberCollector.received(stub2)
  end

  @tag backends: true
  test "Invoices of the same amount" do
    inv = [amount: Money.parse!(1.0, :BCH), required_confirmations: 1]

    {:ok, inv0, _, handler0} = HandlerSubscriberCollector.create_invoice(inv)
    {:ok, inv1, _, handler1} = HandlerSubscriberCollector.create_invoice(inv)

    assert inv0.amount == inv1.amount
    assert inv0.address_id != inv1.address_id
    assert handler0 != handler1
  end

  @tag backends: true, double_spend_timeout: 1_000, do: true
  test "Detect early 0-conf doublespend" do
    {:ok, inv, stub, _} = HandlerSubscriberCollector.create_invoice(required_confirmations: 0)

    BackendMock.tx_seen(inv)
    BackendMock.doublespend(inv)

    HandlerSubscriberCollector.await_status(stub, :uncollectible)

    assert [
             {:invoice_status, :open, _},
             {:invoice_status, :processing, _},
             {:invoice_status, :uncollectible, _}
           ] = HandlerSubscriberCollector.received(stub)
  end
end
