defmodule BackendMockTest do
  use BitPal.IntegrationCase

  @tag backends: [
         {BitPal.BackendMock, auto: true, time_until_tx_seen: 10, time_between_blocks: 5}
       ]
  test "auto" do
    {:ok, _inv1, stub1, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(required_confirmations: 1, amount: 1.0)

    {:ok, _inv3, stub3, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(required_confirmations: 3, amount: 3.0)

    HandlerSubscriberCollector.await_state(stub1, :accepted)
    HandlerSubscriberCollector.await_state(stub3, :accepted)

    assert [
             {:state, :wait_for_tx, _},
             {:state, :wait_for_confirmations},
             {:confirmations, 1},
             {:state, :accepted}
           ] = HandlerSubscriberCollector.received(stub1)

    assert [
             {:state, :wait_for_tx, _},
             {:state, :wait_for_confirmations},
             {:confirmations, 1},
             {:confirmations, 2},
             {:confirmations, 3},
             {:state, :accepted}
           ] = HandlerSubscriberCollector.received(stub3)
  end
end
