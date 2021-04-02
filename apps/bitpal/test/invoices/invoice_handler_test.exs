defmodule InvoiceHandlerTest do
  use BitPal.BackendCase

  @tag :backend
  test "initialize" do
    inv = invoice()
    {:ok, handler} = HandlerSubscriberStub.create_invoice(inv)

    HandlerSubscriberStub.await_state_change(handler, :accepted)
    received = HandlerSubscriberStub.received(handler)

    assert received == [
             {:state_changed, :wait_for_tx},
             {:state_changed, :wait_for_verification},
             {:confirmation, 1},
             {:state_changed, :accepted}
           ]
  end

  # test "recover after handler crash" do
  # end
  #
  # test "recover after node process crash" do
  # end
  #
  # test "recover after node connection crash" do
  # end
  #
  # test "recover after full restart" do
  # end
end
