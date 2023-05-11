defmodule BitPal.ExtNotificationHandlerTest do
  # Some timing issues here
  use ExUnit.Case, async: false
  alias BitPal.ExtNotificationHandler
  alias BitPal.Files

  setup _tags do
    %{event: Faker.Code.isbn()}
  end

  describe "extermal notify script" do
    test "Receive pubsub via external notify cmd", %{event: event} do
      ExtNotificationHandler.subscribe(event)

      # credo:disable-for-next-line
      {_, 0} = System.cmd(Files.notify_path(), [event, "123"], env: [{"MIX_ENV", "test"}])

      assert_receive {:notify, ^event, ["123"]}
    end
  end

  describe "handle notify message" do
    test "Receive pubsub via handle_info", %{event: event} do
      ExtNotificationHandler.subscribe(event)

      send(ExtNotificationHandler, {:notify, [event, "123", "abc"], 0})

      assert_receive {:notify, ^event, ["123", "abc"]}
    end
  end

  describe "parse message" do
    test "skip args that I'm not sure why they sometimes come with" do
      assert {:ok, "event", ["1", "2"]} ==
               ExtNotificationHandler.parse_message([
                 "-p",
                 "/tmp/bitpal_notify_socket",
                 "event",
                 "1",
                 "2"
               ])

      assert {:ok, "event", ["1", "2"]} ==
               ExtNotificationHandler.parse_message([
                 "-p",
                 "/tmp/bitpal_notify_socket",
                 "--",
                 "event",
                 "1",
                 "2"
               ])

      assert {:ok, "event", ["1", "2"]} ==
               ExtNotificationHandler.parse_message([
                 "event",
                 "1",
                 "2"
               ])

      assert {:ok, "event", ["1"]} ==
               ExtNotificationHandler.parse_message([
                 "event",
                 "1"
               ])
    end
  end
end
