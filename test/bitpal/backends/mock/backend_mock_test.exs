defmodule BackendMockTest do
  use BitPal.IntegrationCase

  @tag backends: [
         {BitPal.BackendMock, auto: true, time_until_tx_seen: 10, time_between_blocks: 5}
       ]
  test "auto" do
    {:ok, _inv1, stub1, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(
        required_confirmations: 1,
        amount: Money.parse!(1.0, :BCH)
      )

    {:ok, _inv3, stub3, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(
        required_confirmations: 3,
        amount: Money.parse!(3.0, :BCH)
      )

    HandlerSubscriberCollector.await_status(stub1, :paid)
    HandlerSubscriberCollector.await_status(stub3, :paid)

    assert [
             {:invoice_status, :open, _},
             {:invoice_status, :processing, _},
             {:invoice_status, :paid, _}
           ] = HandlerSubscriberCollector.received(stub1)

    assert [
             {:invoice_status, :open, _},
             {:invoice_status, :processing, _},
             {:invoice_status, :paid, _}
           ] = HandlerSubscriberCollector.received(stub3)
  end
end
