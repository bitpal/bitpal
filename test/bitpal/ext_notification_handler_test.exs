defmodule BitPal.ExtNotificationHandlerTest do
  use ExUnit.Case, async: true
  alias BitPal.ExtNotificationHandler
  alias BitPal.Files

  test "Receive pubsub via external notify cmd" do
    ExtNotificationHandler.subscribe("test_event")
    # credo:disable-for-next-line
    {"", 0} = System.cmd(Files.notify_path(), ["test_event", "123"])

    assert_receive {:notify, "test_event", ["123"]}
  end
end
