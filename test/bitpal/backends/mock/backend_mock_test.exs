defmodule BackendMockTest do
  use BitPal.IntegrationCase

  @tag backends: [
         {BitPal.BackendMock, auto: true, time_until_tx_seen: 10, time_between_blocks: 5}
       ]
  test "auto" do
    {:ok, _inv1, stub1, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(
        required_confirmations: 1,
        amount: 1.0
      )

    {:ok, _inv3, stub3, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(
        required_confirmations: 3,
        amount: 3.0
      )

    HandlerSubscriberCollector.await_msg(stub1, :invoice_paid)
    HandlerSubscriberCollector.await_msg(stub3, :invoice_paid)

    assert [
             {:invoice_finalized, _},
             {:invoice_processing, _},
             {:invoice_paid, _}
           ] = HandlerSubscriberCollector.received(stub1)

    assert [
             {:invoice_finalized, _},
             {:invoice_processing, _},
             {:invoice_processing, _},
             {:invoice_processing, _},
             {:invoice_paid, _}
           ] = HandlerSubscriberCollector.received(stub3)
  end
end
