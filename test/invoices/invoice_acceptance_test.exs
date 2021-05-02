defmodule InvoiceHandlerTest do
  use BitPal.IntegrationCase
  alias BitPal.BackendMock

  @tag backends: true, double_spend_timeout: 1
  test "accept after no double spend in timeout" do
    {:ok, inv, stub, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(required_confirmations: 0)

    BackendMock.tx_seen(inv)

    HandlerSubscriberCollector.await_state(stub, :accepted)

    assert [
             {:state, :wait_for_tx, _},
             {:state, :wait_for_verification},
             {:state, :accepted}
           ] = HandlerSubscriberCollector.received(stub)
  end

  @tag backends: true, double_spend_timeout: 1_000
  test "accept when block is found while waiting for double spend timout" do
    {:ok, inv, stub, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(required_confirmations: 0)

    BackendMock.tx_seen(inv)
    BackendMock.new_block(inv)

    HandlerSubscriberCollector.await_state(stub, :accepted)

    assert [
             {:state, :wait_for_tx, _},
             {:state, :wait_for_verification},
             {:confirmations, 1},
             {:state, :accepted}
           ] = HandlerSubscriberCollector.received(stub)
  end

  @tag backends: true
  test "accept after a confirmation" do
    {:ok, inv, stub, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(required_confirmations: 1)

    BackendMock.tx_seen(inv)
    BackendMock.new_block(inv)

    HandlerSubscriberCollector.await_state(stub, :accepted)

    assert [
             {:state, :wait_for_tx, _},
             {:state, :wait_for_confirmations},
             {:confirmations, 1},
             {:state, :accepted}
           ] = HandlerSubscriberCollector.received(stub)
  end

  @tag backends: true
  test "accepts after multiple confirmations" do
    {:ok, inv, stub, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(required_confirmations: 3)

    BackendMock.tx_seen(inv)
    BackendMock.new_block(inv)
    BackendMock.issue_blocks(5)

    HandlerSubscriberCollector.await_state(stub, :accepted)

    assert [
             {:state, :wait_for_tx, _},
             {:state, :wait_for_confirmations},
             {:confirmations, 1},
             {:confirmations, 2},
             {:confirmations, 3},
             {:state, :accepted}
           ] = HandlerSubscriberCollector.received(stub)
  end

  @tag backends: true, double_spend_timeout: 1
  test "multiple invoices" do
    {:ok, inv0, stub0, _} =
      HandlerSubscriberCollector.create_invoice(amount: 0.1, required_confirmations: 0)

    {:ok, inv1, stub1, _} =
      HandlerSubscriberCollector.create_invoice(amount: 1.0, required_confirmations: 1)

    {:ok, inv2, stub2, _} =
      HandlerSubscriberCollector.create_invoice(amount: 2.0, required_confirmations: 2)

    BackendMock.tx_seen(inv0)
    BackendMock.tx_seen(inv1)
    HandlerSubscriberCollector.await_state(stub0, :accepted)
    HandlerSubscriberCollector.await_state(stub1, :wait_for_confirmations)

    assert [
             {:state, :wait_for_tx, _},
             {:state, :wait_for_verification},
             {:state, :accepted}
           ] = HandlerSubscriberCollector.received(stub0)

    assert [
             {:state, :wait_for_tx, _},
             {:state, :wait_for_confirmations}
           ] = HandlerSubscriberCollector.received(stub1)

    assert [
             {:state, :wait_for_tx, _}
           ] = HandlerSubscriberCollector.received(stub2)

    BackendMock.new_block(inv2)
    HandlerSubscriberCollector.await_msg(stub2, {:confirmations, 1})

    assert [
             {:state, :wait_for_tx, _},
             {:state, :wait_for_confirmations}
           ] = HandlerSubscriberCollector.received(stub1)

    assert [
             {:state, :wait_for_tx, _},
             {:confirmations, 1}
           ] = HandlerSubscriberCollector.received(stub2)

    BackendMock.issue_blocks(2)
    HandlerSubscriberCollector.await_state(stub2, :accepted)

    assert [
             {:state, :wait_for_tx, _},
             {:state, :wait_for_confirmations}
           ] = HandlerSubscriberCollector.received(stub1)

    assert [
             {:state, :wait_for_tx, _},
             {:confirmations, 1},
             {:confirmations, 2},
             {:state, :accepted}
           ] = HandlerSubscriberCollector.received(stub2)
  end

  @tag backends: true, do: true
  test "Invoices of the same amount" do
    inv = [amount: 1.0, required_confirmations: 1]

    {:ok, inv0, _, handler0} = HandlerSubscriberCollector.create_invoice(inv)
    {:ok, inv1, _, handler1} = HandlerSubscriberCollector.create_invoice(inv)

    assert inv0.amount != inv1.amount
    assert handler0 != handler1
  end

  @tag backends: true, double_spend_timeout: 1_000
  test "Detect early 0-conf doublespend" do
    {:ok, inv, stub, _} = HandlerSubscriberCollector.create_invoice(required_confirmations: 0)

    BackendMock.tx_seen(inv)
    BackendMock.doublespend(inv)

    HandlerSubscriberCollector.await_state(stub, {:denied, :doublespend})

    assert [
             {:state, :wait_for_tx, _},
             {:state, :wait_for_verification},
             {:state, {:denied, :doublespend}}
           ] = HandlerSubscriberCollector.received(stub)
  end
end
