defmodule BackendMockTest do
  use BitPal.IntegrationCase

  # NOTE: This sometimes triggers the error:
  #
  # 12:21:21.210 [error] Postgrex.Protocol (#PID<0.662.0>) disconnected: ** (DBConnection.ConnectionError) client #PID<0.792.0> exited
  #
  # The tests still pass, but it's a bit annoying.
  # I don't know why, but it still appears even if we stop_supervised!() everything else before Repo is exited.
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
