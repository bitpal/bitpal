defmodule BackendMockTest do
  use BitPal.BackendCase

  @tag backends: [
         {BitPal.BackendMock, auto: true, time_until_tx_seen: 10, time_between_blocks: 5}
       ]
  test "auto" do
    {:ok, inv1, stub1, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(invoice(required_confirmations: 1, amount: 1.0))

    {:ok, inv3, stub3, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(invoice(required_confirmations: 3, amount: 3.0))

    HandlerSubscriberCollector.await_endstate(stub1, :accepted, inv1)
    HandlerSubscriberCollector.await_endstate(stub3, :accepted, inv3)

    assert HandlerSubscriberCollector.received(stub1) == [
             {:state, :wait_for_tx},
             {:state, :wait_for_confirmations},
             {:confirmations, 1},
             {:state, :accepted, inv1}
           ]

    assert HandlerSubscriberCollector.received(stub3) == [
             {:state, :wait_for_tx},
             {:state, :wait_for_confirmations},
             {:confirmations, 1},
             {:confirmations, 2},
             {:confirmations, 3},
             {:state, :accepted, inv3}
           ]
  end
end
