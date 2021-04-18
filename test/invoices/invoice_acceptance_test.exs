defmodule InvoiceHandlerTest do
  use BitPal.BackendCase
  alias BitPal.BackendMock

  @tag backends: true, double_spend_timeout: 1
  test "accept after no double spend in timeout" do
    inv = invoice(required_confirmations: 0)
    {:ok, inv, stub, _invoice_handler} = HandlerSubscriberCollector.create_invoice(inv)

    BackendMock.tx_seen(inv)

    HandlerSubscriberCollector.await_endstate(stub, :accepted, inv)

    assert HandlerSubscriberCollector.received(stub) == [
             {:state, :wait_for_tx},
             {:state, :wait_for_verification},
             {:state, :accepted, inv}
           ]
  end

  @tag backends: true, double_spend_timeout: 1_000
  test "accept when block is found while waiting for double spend timout" do
    inv = invoice(required_confirmations: 0)
    {:ok, inv, stub, _invoice_handler} = HandlerSubscriberCollector.create_invoice(inv)

    BackendMock.tx_seen(inv)
    BackendMock.new_block(inv)

    HandlerSubscriberCollector.await_endstate(stub, :accepted, inv)

    assert HandlerSubscriberCollector.received(stub) == [
             {:state, :wait_for_tx},
             {:state, :wait_for_verification},
             {:confirmations, 1},
             {:state, :accepted, inv}
           ]
  end

  @tag backends: true
  test "accept after a confirmation" do
    inv = invoice(required_confirmations: 1)
    {:ok, inv, stub, _invoice_handler} = HandlerSubscriberCollector.create_invoice(inv)

    BackendMock.tx_seen(inv)
    BackendMock.new_block(inv)

    HandlerSubscriberCollector.await_endstate(stub, :accepted, inv)

    assert HandlerSubscriberCollector.received(stub) == [
             {:state, :wait_for_tx},
             {:state, :wait_for_confirmations},
             {:confirmations, 1},
             {:state, :accepted, inv}
           ]
  end

  @tag backends: true
  test "accepts after multiple confirmations" do
    inv = invoice(required_confirmations: 3)
    {:ok, inv, stub, _invoice_handler} = HandlerSubscriberCollector.create_invoice(inv)

    BackendMock.tx_seen(inv)
    BackendMock.new_block(inv)
    BackendMock.issue_blocks(5)

    HandlerSubscriberCollector.await_endstate(stub, :accepted, inv)

    assert HandlerSubscriberCollector.received(stub) == [
             {:state, :wait_for_tx},
             {:state, :wait_for_confirmations},
             {:confirmations, 1},
             {:confirmations, 2},
             {:confirmations, 3},
             {:state, :accepted, inv}
           ]
  end

  @tag backends: true, double_spend_timeout: 1
  test "multiple invoices" do
    inv0 = invoice(amount: 0.1, required_confirmations: 0)
    {:ok, inv0, stub0, _} = HandlerSubscriberCollector.create_invoice(inv0)

    inv1 = invoice(amount: 1.0, required_confirmations: 1)
    {:ok, inv1, stub1, _} = HandlerSubscriberCollector.create_invoice(inv1)

    inv2 = invoice(amount: 2.0, required_confirmations: 2)
    {:ok, inv2, stub2, _} = HandlerSubscriberCollector.create_invoice(inv2)

    BackendMock.tx_seen(inv0)
    BackendMock.tx_seen(inv1)
    HandlerSubscriberCollector.await_endstate(stub0, :accepted, inv0)
    HandlerSubscriberCollector.await_state(stub1, :wait_for_confirmations)

    assert HandlerSubscriberCollector.received(stub0) == [
             {:state, :wait_for_tx},
             {:state, :wait_for_verification},
             {:state, :accepted, inv0}
           ]

    assert HandlerSubscriberCollector.received(stub1) == [
             {:state, :wait_for_tx},
             {:state, :wait_for_confirmations}
           ]

    assert HandlerSubscriberCollector.received(stub2) == [
             {:state, :wait_for_tx}
           ]

    BackendMock.new_block(inv2)
    HandlerSubscriberCollector.await_msg(stub2, {:confirmations, 1})

    assert HandlerSubscriberCollector.received(stub1) == [
             {:state, :wait_for_tx},
             {:state, :wait_for_confirmations}
           ]

    assert HandlerSubscriberCollector.received(stub2) == [
             {:state, :wait_for_tx},
             {:confirmations, 1}
           ]

    BackendMock.issue_blocks(2)
    HandlerSubscriberCollector.await_endstate(stub2, :accepted, inv2)

    assert HandlerSubscriberCollector.received(stub1) == [
             {:state, :wait_for_tx},
             {:state, :wait_for_confirmations}
           ]

    assert HandlerSubscriberCollector.received(stub2) == [
             {:state, :wait_for_tx},
             {:confirmations, 1},
             {:confirmations, 2},
             {:state, :accepted, inv2}
           ]
  end

  @tag backends: true
  test "Invoices of the same amount" do
    inv = invoice(amount: 1.0, required_confirmations: 1)

    {:ok, inv0, _, handler0} = HandlerSubscriberCollector.create_invoice(inv)
    {:ok, inv1, _, handler1} = HandlerSubscriberCollector.create_invoice(inv)

    assert inv0.amount != inv1.amount
    assert handler0 != handler1
  end

  @tag backends: true, double_spend_timeout: 1_000
  test "Detect early 0-conf doublespend" do
    inv = invoice(required_confirmations: 0)

    {:ok, inv, stub, _} = HandlerSubscriberCollector.create_invoice(inv)

    BackendMock.tx_seen(inv)
    BackendMock.doublespend(inv)

    HandlerSubscriberCollector.await_endstate(stub, {:denied, :doublespend}, inv)

    assert HandlerSubscriberCollector.received(stub) == [
             {:state, :wait_for_tx},
             {:state, :wait_for_verification},
             {:state, {:denied, :doublespend}, inv}
           ]
  end
end
