defmodule BackendMockTest do
  use BitPal.IntegrationCase, async: true

  @tag backends: [
         {BitPal.BackendMock, auto: true, time_until_tx_seen: 10, time_between_blocks: 5}
       ]
  test "auto", %{currency_id: currency_id} do
    {:ok, _inv1, stub1, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(
        currency_id: currency_id,
        required_confirmations: 1,
        amount: 1.0
      )

    {:ok, _inv3, stub3, _invoice_handler} =
      HandlerSubscriberCollector.create_invoice(
        currency_id: currency_id,
        required_confirmations: 3,
        amount: 3.0
      )

    HandlerSubscriberCollector.await_msg(stub1, {:invoice, :paid})
    HandlerSubscriberCollector.await_msg(stub3, {:invoice, :paid})

    assert [
             {{:invoice, :finalized}, _},
             {{:invoice, :processing}, _},
             {{:invoice, :paid}, _}
           ] = HandlerSubscriberCollector.received(stub1)

    assert [
             {{:invoice, :finalized}, _},
             {{:invoice, :processing}, _},
             {{:invoice, :processing}, _},
             {{:invoice, :processing}, _},
             {{:invoice, :paid}, _}
           ] = HandlerSubscriberCollector.received(stub3)
  end
end
